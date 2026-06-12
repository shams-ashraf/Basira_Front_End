print("START")
import cv2
import torch
from PIL import Image
from transformers import BlipProcessor, BlipForConditionalGeneration
from peft import PeftModel

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

BASE_MODEL = "Salesforce/blip-image-captioning-base"
ADAPTER_PATH = "blip_model"

print("Loading processor...")
processor = BlipProcessor.from_pretrained(BASE_MODEL)

print("Loading base model...")
base_model = BlipForConditionalGeneration.from_pretrained(BASE_MODEL)

print("Loading adapter...")
model = PeftModel.from_pretrained(base_model, ADAPTER_PATH)

model = model.to(DEVICE)
model.eval()

print("Opening camera...")

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Camera not found")
    exit()

last_caption = ""
frame_count = 0

while True:

    ret, frame = cap.read()

    if not ret:
        break

    frame_count += 1

    if frame_count % 30 == 0:

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        pil_image = Image.fromarray(rgb)

        inputs = processor(
            images=pil_image,
            return_tensors="pt"
        )

        inputs = {
            k: v.to(DEVICE)
            for k, v in inputs.items()
        }

        with torch.no_grad():

            output = model.generate(
                **inputs,
                max_new_tokens=30,
                num_beams=3
            )

        last_caption = processor.decode(
            output[0],
            skip_special_tokens=True
        )

        print("Scene:", last_caption)

    cv2.rectangle(frame, (10, 10), (1250, 60), (0, 0, 0), -1)

    cv2.putText(
        frame,
        last_caption,
        (20, 45),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    cv2.imshow("Live Scene Summary", frame)

    key = cv2.waitKey(1)

    if key == ord("q"):
        break

cap.release()

cv2.destroyAllWindows()