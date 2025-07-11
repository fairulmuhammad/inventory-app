from flask import Flask, jsonify, request

app = Flask(__name__)

inventory = [
    {"id": 1, "name": "Laptop", "stock": 10},
    {"id": 2, "name": "Mouse", "stock": 50},
]

@app.route("/")
def index():
    return "Inventory Service is running!"

@app.route("/items", methods=["GET"])
def get_items():
    return jsonify(inventory)

@app.route("/items", methods=["POST"])
def add_item():
    data = request.get_json()
    inventory.append(data)
    return jsonify({"message": "Item added!"}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
