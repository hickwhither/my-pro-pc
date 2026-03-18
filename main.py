from flask import Flask, send_from_directory, jsonify, request, send_file, Response
import json
import os


app = Flask(__name__)


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
        with open('settings.json', 'r') as f:
            data = json.load(f)
        return jsonify(data)
    elif request.method == 'POST':
        data = request.get_json()
        with open('settings.json', 'r') as f:
            current = json.load(f)
        if data['action'] == 'add':
            current[data['key']] = data['value']
        elif data['action'] == 'remove':
            if data['key'] in current:
                del current[data['key']]
        elif data['action'] == 'update':
            current[data['key']] = data['value']
        with open('settings.json', 'w') as f:
            json.dump(current, f, indent=4)
        return jsonify({'status': 'ok'})

@app.route('/updateSettings', methods=['GET'])
def update_settings():
    key = request.args.get('key')
    value_str = request.args.get('value')
    if value_str:
        value = json.loads(value_str) if value_str.startswith(('{', '[', '"')) or value_str in {'true', 'false', 'null'} or value_str.replace('.', '', 1).lstrip('-').isdigit() else value_str
    else:
        value = None
    with open('settings.json', 'r') as f:
        current = json.load(f)
    current[key] = value
    with open('settings.json', 'w') as f:
        json.dump(current, f, indent=4)
    print(f"Updated setting {key} to {value}")
    return jsonify({'status': 'ok'})

@app.route('/src/<path:filepath>')
def src_file(filepath):
    return send_from_directory('src', filepath)

if __name__ == '__main__':
    app.run(debug=True)
