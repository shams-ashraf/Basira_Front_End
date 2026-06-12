import asyncio
from typing import Callable, Dict, List, Any
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EventBus:
    """
    A simple in-memory asynchronous Event Bus.
    Handles communication between Fast Path, Smart Path, and Orchestrator.
    """
    def __init__(self):
        self._subscribers: Dict[str, List[Callable]] = {}
        self._queue = asyncio.Queue()
        self._running = False
        self._task = None

    def subscribe(self, event_type: str, callback: Callable):
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        self._subscribers[event_type].append(callback)
        logger.info(f"Subscribed to event: {event_type}")

    async def publish(self, event_type: str, data: Any = None):
        """Publish an event to the bus."""
        await self._queue.put({"type": event_type, "data": data})

    async def _process_events(self):
        while self._running:
            event = await self._queue.get()
            event_type = event["type"]
            data = event["data"]
            
            if event_type in self._subscribers:
                for callback in self._subscribers[event_type]:
                    try:
                        # Schedule callbacks concurrently
                        asyncio.create_task(self._safe_call(callback, data))
                    except Exception as e:
                        logger.error(f"Error dispatching event {event_type}: {e}")
            self._queue.task_done()

    async def _safe_call(self, callback: Callable, data: Any):
        try:
            if asyncio.iscoroutinefunction(callback):
                await callback(data)
            else:
                callback(data)
        except Exception as e:
            logger.error(f"Error in callback for event data {data}: {e}")

    def start(self):
        """Start the event processing loop."""
        if not self._running:
            self._running = True
            self._task = asyncio.create_task(self._process_events())
            logger.info("Event Bus started.")

    async def stop(self):
        """Stop the event processing loop."""
        self._running = False
        if self._task:
            self._task.cancel()
        logger.info("Event Bus stopped.")

# Global instance
bus = EventBus()
