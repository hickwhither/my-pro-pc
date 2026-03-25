import json
from pathlib import Path
from typing import Any

import gradio as gr
import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse

BASE_DIR = Path(__file__).resolve().parent
SETTINGS_PATH = BASE_DIR / "settings.json"
SRC_DIR = BASE_DIR / "src"


def ensure_settings_file() -> None:
    if not SETTINGS_PATH.exists():
        SETTINGS_PATH.write_text("{}\n", encoding="utf-8")


def load_settings() -> dict[str, Any]:
    ensure_settings_file()
    with SETTINGS_PATH.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_settings(data: dict[str, Any]) -> None:
    with SETTINGS_PATH.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=4)


def to_lua(value: Any) -> str:
    if isinstance(value, dict):
        items = []
        for key, nested_value in value.items():
            items.append(f'[{json.dumps(str(key))}] = {to_lua(nested_value)}')
        return "{" + ", ".join(items) + "}"
    if isinstance(value, list):
        return "{" + ", ".join(to_lua(item) for item in value) + "}"
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, str):
        return json.dumps(value)
    return str(value)


def parse_input_value(raw_value: str, value_type: str) -> Any:
    if value_type == "bool":
        return raw_value.strip().lower() in {"true", "1", "yes", "on"}
    if value_type == "number":
        numeric = float(raw_value)
        return int(numeric) if numeric.is_integer() else numeric
    if value_type == "json":
        return json.loads(raw_value)
    if value_type == "null":
        return None
    return raw_value


def parse_query_value(value_str: str | None) -> Any:
    if value_str is None:
        return None

    try:
        return json.loads(value_str)
    except json.JSONDecodeError:
        return value_str


app = FastAPI(title="Settings Manager")


@app.get("/settings.lua")
def settings_lua() -> PlainTextResponse:
    data = load_settings()
    return PlainTextResponse("return " + to_lua(data))


@app.get("/settings")
def get_settings() -> JSONResponse:
    return JSONResponse(load_settings())


@app.post("/settings")
def update_settings(payload: dict[str, Any]) -> JSONResponse:
    action = payload.get("action")
    key = payload.get("key")

    if not key:
        raise HTTPException(status_code=400, detail="Missing key")

    current = load_settings()

    if action in {"add", "update"}:
        current[key] = payload.get("value")
    elif action == "remove":
        current.pop(key, None)
    else:
        raise HTTPException(status_code=400, detail="Invalid action")

    save_settings(current)
    return JSONResponse({"status": "ok"})


@app.get("/updateSettings")
def update_setting_query(
    key: str = Query(...),
    value: str | None = Query(default=None),
) -> JSONResponse:
    current = load_settings()
    parsed_value = parse_query_value(value)
    current[key] = parsed_value
    save_settings(current)
    return JSONResponse({"status": "ok"})


@app.get("/src/{filepath:path}")
def get_src_file(filepath: str) -> FileResponse:
    target = (SRC_DIR / filepath).resolve()
    if not target.is_file() or SRC_DIR not in target.parents:
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(target)


def add_setting(key: str, value: str, value_type: str) -> tuple[dict[str, Any], str]:
    if not key.strip():
        return load_settings(), "⚠️ Key không được để trống."

    current = load_settings()
    if key in current:
        return current, f"⚠️ Key '{key}' đã tồn tại, hãy dùng Update."

    try:
        current[key] = parse_input_value(value, value_type)
    except (ValueError, json.JSONDecodeError) as exc:
        return current, f"❌ Giá trị không hợp lệ: {exc}"

    save_settings(current)
    return current, f"✅ Đã thêm '{key}'."


def update_setting(key: str, value: str, value_type: str) -> tuple[dict[str, Any], str]:
    if not key.strip():
        return load_settings(), "⚠️ Key không được để trống."

    current = load_settings()
    if key not in current:
        return current, f"⚠️ Key '{key}' chưa tồn tại, hãy dùng Add."

    try:
        current[key] = parse_input_value(value, value_type)
    except (ValueError, json.JSONDecodeError) as exc:
        return current, f"❌ Giá trị không hợp lệ: {exc}"

    save_settings(current)
    return current, f"✅ Đã cập nhật '{key}'."


def remove_setting(key: str) -> tuple[dict[str, Any], str]:
    if not key.strip():
        return load_settings(), "⚠️ Key không được để trống."

    current = load_settings()
    if key not in current:
        return current, f"⚠️ Không tìm thấy '{key}'."

    current.pop(key)
    save_settings(current)
    return current, f"✅ Đã xóa '{key}'."


def refresh_settings() -> tuple[dict[str, Any], str]:
    return load_settings(), "🔄 Đã tải lại settings.json"


with gr.Blocks(title="Settings Manager") as demo:
    gr.Markdown("""
    # Settings Manager
    Giao diện Gradio để quản lý `settings.json` nhanh gọn và clean hơn Flask route UI cũ.
    """)

    settings_view = gr.JSON(label="Current settings", value=load_settings)
    status = gr.Markdown("Sẵn sàng.")

    with gr.Row():
        key_input = gr.Textbox(label="Key", placeholder="vd: flyEnabled")
        value_input = gr.Textbox(label="Value", placeholder="vd: true hoặc {\"speed\": 10}")
        type_input = gr.Dropdown(
            choices=["string", "bool", "number", "json", "null"],
            value="string",
            label="Type",
        )

    with gr.Row():
        add_button = gr.Button("Add", variant="primary")
        update_button = gr.Button("Update")
        remove_button = gr.Button("Remove", variant="stop")
        refresh_button = gr.Button("Refresh")

    add_button.click(add_setting, [key_input, value_input, type_input], [settings_view, status])
    update_button.click(update_setting, [key_input, value_input, type_input], [settings_view, status])
    remove_button.click(remove_setting, [key_input], [settings_view, status])
    refresh_button.click(refresh_settings, outputs=[settings_view, status])

app = gr.mount_gradio_app(app, demo, path="/")


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=7860)
