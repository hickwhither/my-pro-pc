from flask import Flask, send_from_directory, jsonify, request, send_file, Response
from flask_socketio import SocketIO, emit
import json
import os
from threading import Lock


app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")
settings_lock = Lock()


def to_lua(value):
    if isinstance(value, dict):
        items = []
        for key, nested_value in value.items():
            items.append(f'[{json.dumps(str(key))}] = {to_lua(nested_value)}')
        return '{' + ', '.join(items) + '}'
    if isinstance(value, list):
        items = [to_lua(item) for item in value]
        return '{' + ', '.join(items) + '}'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if value is None:
        return 'nil'
    if isinstance(value, str):
        return json.dumps(value)
    return str(value)

@app.route('/')
def index():
    return send_file('index.html')

@app.route('/settings.lua')
def settings_lua():
    with open('settings.json', 'r') as f:
        data = json.load(f)
    return Response('return ' + to_lua(data), mimetype='text/plain')


@app.route('/settings', methods=['GET', 'POST'])
def settings():
    if request.method == 'GET':
        data = load_settings_file()
        return jsonify(data)
    elif request.method == 'POST':
        data = request.get_json()
        current = apply_settings_action(data)
        socketio.emit('settings:snapshot', current)
        return jsonify({'status': 'ok'})

@app.route('/updateSettings', methods=['GET'])
def update_settings():
    key = request.args.get('key')
    value_str = request.args.get('value')
    if value_str:
        value = json.loads(value_str) if value_str.startswith(('{', '[', '"')) or value_str in {'true', 'false', 'null'} or value_str.replace('.', '', 1).lstrip('-').isdigit() else value_str
    else:
        value = None
    current = apply_settings_action({'action': 'update', 'key': key, 'value': value})
    socketio.emit('settings:snapshot', current)
    print(f"Updated setting {key} to {value}")
    return jsonify({'status': 'ok'})

@app.route('/src/<path:filepath>')
def src_file(filepath):
    return send_from_directory('src', filepath)

def load_settings_file():
    with settings_lock:
        with open('settings.json', 'r') as f:
            return json.load(f)

def save_settings_file(data):
    with settings_lock:
        with open('settings.json', 'w') as f:
            json.dump(data, f, indent=4)

def apply_settings_action(data):
    current = load_settings_file()
    action = data.get('action')
    key = data.get('key')

    if action == 'add' or action == 'update':
        current[key] = data.get('value')
    elif action == 'remove' and key in current:
        del current[key]

    save_settings_file(current)
    return current

@socketio.on('connect')
def on_connect():
    emit('settings:snapshot', load_settings_file())

@socketio.on('settings:get')
def on_settings_get():
    emit('settings:snapshot', load_settings_file())

@socketio.on('settings:command')
def on_settings_command(payload):
    current = apply_settings_action(payload or {})
    socketio.emit('settings:snapshot', current)

if __name__ == '__main__':
    socketio.run(app, debug=True)
