import os
import wave
import json
import uuid
import pyttsx3
from vosk import Model, KaldiRecognizer

class VoiceService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(VoiceService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
            
        print("Loading Voice Models...")
        model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../model'))
        if not os.path.exists(model_path):
            print(f"Vosk model not found at {model_path}")
            self.stt_model = None
        else:
            try:
                self.stt_model = Model(model_path)
            except Exception as e:
                print(f"Failed to load Vosk model: {e}")
                self.stt_model = None
            
        # TTS engine will be initialized per-thread in text_to_speech
        
        self.audio_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../audio'))
        os.makedirs(self.audio_dir, exist_ok=True)
        
        self._initialized = True

    def get_stt_recognizer(self, sample_rate=16000):
        if not self.stt_model:
            return None
        return KaldiRecognizer(self.stt_model, sample_rate)

    def process_audio_chunk(self, recognizer, chunk):
        if recognizer.AcceptWaveform(chunk):
            result = json.loads(recognizer.Result())
            return result.get("text", ""), True
        else:
            partial = json.loads(recognizer.PartialResult())
            return partial.get("partial", ""), False

    def text_to_speech(self, text):
        filename = f"{uuid.uuid4()}.wav"
        filepath = os.path.join(self.audio_dir, filename)
        
        try:
            import pythoncom
            pythoncom.CoInitialize()
        except ImportError:
            pass
            
        try:
            engine = pyttsx3.init()
            engine.setProperty('rate', 150)
            engine.setProperty('volume', 1.0)
            engine.save_to_file(text, filepath)
            engine.runAndWait()
        except Exception as e:
            print(f"TTS Engine error: {e}")
            # Fallback or just ignore if it fails
        finally:
            try:
                import pythoncom
                pythoncom.CoUninitialize()
            except ImportError:
                pass
                
        return filename, filepath

voice_service = VoiceService()
