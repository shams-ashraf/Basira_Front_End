import cv2
import torch
import threading
import pyttsx3

from PIL import Image

from transformers import (
    VisionEncoderDecoderModel,
    ViTImageProcessor,
    AutoTokenizer
)

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

MODEL_PATH = "final_model"

print("Loading model...")

model = VisionEncoderDecoderModel.from_pretrained(
    MODEL_PATH,
    torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32
).to(DEVICE)

processor = ViTImageProcessor.from_pretrained(MODEL_PATH)

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)

model.eval()

if DEVICE == "cuda":
    torch.backends.cudnn.benchmark = True

speaker = pyttsx3.init()

speaker.setProperty("rate", 145)

voices = speaker.getProperty("voices")

if len(voices) > 1:
    speaker.setProperty("voice", voices[1].id)

speech_lock = threading.Lock()

print("Opening camera...")

cap = cv2.VideoCapture(0)

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

if not cap.isOpened():
    print("Camera not found")
    exit()

latest_sentence = "Starting..."
last_spoken = ""
processing = False


def clean_caption(text):

    text = text.lower().strip()

    text = " ".join(text.split())

    replacements = {
        "a ": "",
        "an ": "",
        "the ": ""
    }

    for k, v in replacements.items():
        text = text.replace(k, v)

    text = text.replace("womis", "woman is")
    text = text.replace("womsitting", "woman sitting")

    return text


def make_sentence(caption):

    caption = clean_caption(caption)

    if "person" in caption or "woman" in caption or "man" in caption:
        return f"There is someone in front of you. {caption}"

    if "dog" in caption:
        return f"There is a dog nearby. {caption}"

    if "cat" in caption:
        return f"There is a cat nearby. {caption}"

    if "car" in caption:
        return f"There is a car ahead. {caption}"

    if "phone" in caption:
        return f"Someone is using a phone. {caption}"

    if "bed" in caption:
        return f"There is a bed nearby. {caption}"

    return f"I can see {caption}"


def speak(text):

    with speech_lock:

        speaker.say(text)
        speaker.runAndWait()


def generate_caption(frame):

    global latest_sentence
    global last_spoken
    global processing

    try:

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        pil_image = Image.fromarray(rgb)

        pixel_values = processor(
            images=pil_image,
            return_tensors="pt"
        ).pixel_values.to(DEVICE)

        if DEVICE == "cuda":
            pixel_values = pixel_values.half()

        with torch.no_grad():

            output_ids = model.generate(
                pixel_values,
                max_length=18,
                num_beams=1,
                do_sample=False
            )

        caption = tokenizer.decode(
            output_ids[0],
            skip_special_tokens=True
        )

        caption = " ".join(caption.split())

        sentence = make_sentence(caption)

        latest_sentence = sentence

        print(sentence)

        if sentence != last_spoken and len(sentence) > 8:

            last_spoken = sentence

            threading.Thread(
                target=speak,
                args=(sentence,),
                daemon=True
            ).start()

    except Exception as e:

        print(e)

    processing = False


frame_counter = 0

while True:

    ret, frame = cap.read()

    if not ret:
        break

    frame_counter += 1

    if frame_counter % 120 == 0 and not processing:

        processing = True

        small_frame = cv2.resize(
            frame,
            (320, 240)
        )

        threading.Thread(
            target=generate_caption,
            args=(small_frame.copy(),),
            daemon=True
        ).start()

    cv2.rectangle(
        frame,
        (10, 10),
        (1200, 60),
        (0, 0, 0),
        -1
    )

    cv2.putText(
        frame,
        latest_sentence,
        (20, 45),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2
    )

    cv2.imshow(
        "Blind Assistant",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()

cv2.destroyAllWindows()