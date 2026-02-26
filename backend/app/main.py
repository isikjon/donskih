import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.api.v1 import auth, users, bot_webhook, subscription, content, admin_content, chat, admin_users

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    os.makedirs("/app/static/chat", exist_ok=True)
    os.makedirs("/app/static/avatars", exist_ok=True)
    logger.info(f"Starting {settings.app_name} ({settings.app_env})")
    yield
    logger.info("Shutting down")


app = FastAPI(
    title=settings.app_name,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(bot_webhook.router, prefix="/api/v1")
app.include_router(subscription.router, prefix="/api/v1")
app.include_router(content.router, prefix="/api/v1")
app.include_router(admin_content.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(admin_users.router, prefix="/api/v1")

os.makedirs("/app/static/chat", exist_ok=True)
os.makedirs("/app/static/avatars", exist_ok=True)
app.mount("/static", StaticFiles(directory="/app/static"), name="static")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception(f"Unhandled error: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "internal_error", "detail": "An unexpected error occurred"},
    )


@app.get("/health")
async def health():
    return {"status": "ok", "service": settings.app_name}
