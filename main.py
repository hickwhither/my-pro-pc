from flask import Flask, send_from_directory, jsonify, request, send_file
import json
import os

app = Flask(__name__)

@app.route('/')
def index():
    return send_file('index.html')

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
        value = json.loads(value_str)
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
