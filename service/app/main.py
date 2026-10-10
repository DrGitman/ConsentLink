from fastapi import FastAPI

app = FastAPI(title="ConsentLink Service")


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}
