"""
Chat message endpoint.

Rate-limited to 20 requests/minute per IP.
Session validity is checked before every message is processed.
"""

from fastapi import APIRouter, Request, HTTPException
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..models.schemas import ChatRequest, ChatResponse
from ..services.chat_service import get_session, process_message

router = APIRouter(prefix="/api/chat", tags=["Chat"])
limiter = Limiter(key_func=get_remote_address)


@router.post("/message", response_model=ChatResponse)
@limiter.limit("20/minute")
async def send_message(request: Request, body: ChatRequest) -> ChatResponse:
    """Accept a student message and advance the conversation FSM."""

    # Validate session before delegating — avoids unnecessary processing
    if get_session(body.session_id) is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired session. Please re-verify your identity.",
        )

    return process_message(body.session_id, body.message)
