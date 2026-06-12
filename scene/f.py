import cv2
import torch
import threading
import pyttsx3
import time

from PIL import Image

from transformers import AutoProcessor, AutoModelForCausalLM

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

MODEL_ID = "microsoft/Florence-2-base"

print("Loading Florence-2...")

model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    trust_remote_code=True,
    torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32
).to(DEVICE)

processor = AutoProcessor.from_pretrained(
    MODEL_ID,
    trust_remote_code=True
)

model.eval()

speaker = pyttsx3.init()

speaker.setProperty("rate", 115)

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
last_speak_time = 0
processing = False


def clean_text(text):

    text = text.lower().strip()

    text = " ".join(text.split())

    text = text.replace("the image shows", "")
    text = text.replace("this image shows", "")
    text = text.replace("there is", "")

    return text.strip()


def make_sentence(text):

    text = clean_text(text)

    if len(text) < 4:
        return None

    if "person" in text or "woman" in text or "man" in text:
        return f"Someone is in front of you. {text}"

    if "dog" in text:
        return f"There is a dog nearby. {text}"

    if "car" in text:
        return f"There is a car ahead. {text}"

    if "chair" in text:
        return f"There is a chair nearby. {text}"

    return f"I can see {text}"


def speak(text):

    with speech_lock:

        speaker.say(text)
        speaker.runAndWait()


def generate_caption(frame):

    global latest_sentence
    global last_spoken
    global last_speak_time
    global processing

    try:

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        image = Image.fromarray(rgb)

        prompt = "<MORE_DETAILED_CAPTION>"

        inputs = processor(
            text=prompt,
            images=image,
            return_tensors="pt"
        ).to(DEVICE)

        if DEVICE == "cuda":

            inputs["pixel_values"] = inputs[
                "pixel_values"
            ].half()

        with torch.no_grad():

            generated_ids = model.generate(
                input_ids=inputs["input_ids"],
                pixel_values=inputs["pixel_values"],
                max_new_tokens=40,
                num_beams=2,
                do_sample=False
            )

        generated_text = processor.batch_decode(
            generated_ids,
            skip_special_tokens=True
        )[0]

        sentence = make_sentence(generated_text)

        if sentence is None:

            processing = False
            return

        latest_sentence = sentence

        print(sentence)

        if (
            sentence != last_spoken
            and time.time() - last_speak_time > 8
        ):

            last_spoken = sentence

            last_speak_time = time.time()

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

    if frame_counter % 300 == 0 and not processing:

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
        "Florence-2 Blind Assistant",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()

cv2.destroyAllWindows()