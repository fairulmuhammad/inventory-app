from flask import Flask, jsonify, request
import logging
from datetime import datetime
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter, Histogram, Gauge
import time

app = Flask(__name__)

# Configure Prometheus metrics
metrics = PrometheusMetrics(app)
metrics.info('app_info', 'Application info', version='1.0.0')

# Custom metrics
REQUEST_COUNT = Counter('inventory_requests_total', 'Total number of requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('inventory_request_duration_seconds', 'Request latency')
INVENTORY_SIZE = Gauge('inventory_items_total', 'Total number of items in inventory')
ERROR_COUNT = Counter('inventory_errors_total', 'Total number of errors', ['error_type'])

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

inventory = [
    {"id": 1, "name": "Laptop", "stock": 10, "created_at": "2024-01-01T00:00:00Z"},
    {"id": 2, "name": "Mouse", "stock": 50, "created_at": "2024-01-01T00:00:00Z"},
]

# Update inventory size metric
INVENTORY_SIZE.set(len(inventory))

def validate_item_data(data):
    """Validate item data"""
    required_fields = ['name', 'stock']
    if not data:
        return False, "No data provided"
    
    for field in required_fields:
        if field not in data:
            return False, f"Missing required field: {field}"
    
    if not isinstance(data['stock'], int) or data['stock'] < 0:
        return False, "Stock must be a non-negative integer"
    
    if not isinstance(data['name'], str) or len(data['name'].strip()) == 0:
        return False, "Name must be a non-empty string"
    
    return True, "Valid"

@app.before_request
def before_request():
    """Log request details and start timer"""
    request.start_time = time.time()
    logger.info(f"Request: {request.method} {request.path} from {request.remote_addr}")
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint or 'unknown').inc()

@app.after_request
def after_request(response):
    """Log response details and record metrics"""
    if hasattr(request, 'start_time'):
        request_latency = time.time() - request.start_time
        REQUEST_LATENCY.observe(request_latency)
        logger.info(f"Response: {response.status_code} in {request_latency:.4f}s")
    return response

@app.errorhandler(Exception)
def handle_exception(e):
    """Global error handler"""
    ERROR_COUNT.labels(error_type=type(e).__name__).inc()
    logger.error(f"Unhandled exception: {str(e)}")
    return jsonify({"error": "Internal server error"}), 500

@app.route("/")
def index():
    logger.info("Health check endpoint accessed")
    return jsonify({"message": "Inventory Service is running!", "timestamp": datetime.utcnow().isoformat()})

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy", 
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "inventory_count": len(inventory)
    })

@app.route("/metrics")
def custom_metrics():
    """Custom metrics endpoint"""
    return jsonify({
        "total_items": len(inventory),
        "total_stock": sum(item["stock"] for item in inventory),
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route("/items", methods=["GET"])
def get_items():
    logger.info("Fetching all items")
    return jsonify({"items": inventory, "count": len(inventory)})

@app.route("/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    logger.info(f"Fetching item with id: {item_id}")
    item = next((item for item in inventory if item["id"] == item_id), None)
    if item:
        return jsonify(item)
    else:
        logger.warning(f"Item with id {item_id} not found")
        ERROR_COUNT.labels(error_type='ItemNotFound').inc()
        return jsonify({"error": "Item not found"}), 404

@app.route("/items", methods=["POST"])
def add_item():
    try:
        data = request.get_json()
        logger.info(f"Adding new item: {data}")
        
        is_valid, message = validate_item_data(data)
        if not is_valid:
            logger.error(f"Invalid item data: {message}")
            ERROR_COUNT.labels(error_type='ValidationError').inc()
            return jsonify({"error": message}), 400
        
        # Generate new ID
        new_id = max([item["id"] for item in inventory], default=0) + 1
        
        new_item = {
            "id": new_id,
            "name": data["name"].strip(),
            "stock": data["stock"],
            "created_at": datetime.utcnow().isoformat() + "Z"
        }
        
        inventory.append(new_item)
        INVENTORY_SIZE.set(len(inventory))
        logger.info(f"Item added successfully: {new_item}")
        return jsonify({"message": "Item added!", "item": new_item}), 201
        
    except Exception as e:
        logger.error(f"Error adding item: {str(e)}")
        ERROR_COUNT.labels(error_type='InternalError').inc()
        return jsonify({"error": "Internal server error"}), 500

@app.route("/items/<int:item_id>", methods=["PUT"])
def update_item(item_id):
    try:
        data = request.get_json()
        logger.info(f"Updating item {item_id}: {data}")
        
        item = next((item for item in inventory if item["id"] == item_id), None)
        if not item:
            logger.warning(f"Item with id {item_id} not found for update")
            ERROR_COUNT.labels(error_type='ItemNotFound').inc()
            return jsonify({"error": "Item not found"}), 404
        
        is_valid, message = validate_item_data(data)
        if not is_valid:
            logger.error(f"Invalid item data for update: {message}")
            ERROR_COUNT.labels(error_type='ValidationError').inc()
            return jsonify({"error": message}), 400
        
        item["name"] = data["name"].strip()
        item["stock"] = data["stock"]
        item["updated_at"] = datetime.utcnow().isoformat() + "Z"
        
        logger.info(f"Item updated successfully: {item}")
        return jsonify({"message": "Item updated!", "item": item})
        
    except Exception as e:
        logger.error(f"Error updating item {item_id}: {str(e)}")
        ERROR_COUNT.labels(error_type='InternalError').inc()
        return jsonify({"error": "Internal server error"}), 500

@app.route("/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    try:
        logger.info(f"Deleting item with id: {item_id}")
        
        item = next((item for item in inventory if item["id"] == item_id), None)
        if not item:
            logger.warning(f"Item with id {item_id} not found for deletion")
            ERROR_COUNT.labels(error_type='ItemNotFound').inc()
            return jsonify({"error": "Item not found"}), 404
        
        inventory.remove(item)
        INVENTORY_SIZE.set(len(inventory))
        logger.info(f"Item deleted successfully: {item}")
        return jsonify({"message": "Item deleted!", "deleted_item": item})
        
    except Exception as e:
        logger.error(f"Error deleting item {item_id}: {str(e)}")
        ERROR_COUNT.labels(error_type='InternalError').inc()
        return jsonify({"error": "Internal server error"}), 500

def get_host():
    """
    Determine appropriate host binding based on environment.
    Returns 0.0.0.0 only in containerized environments for security.
    """
    import os
    
    # Check if running in Docker container
    if os.path.exists('/.dockerenv'):
        return "0.0.0.0"  # Docker container - allow external access
    
    # Check environment variable
    if os.getenv('FLASK_ENV') == 'production' and os.getenv('ALLOW_EXTERNAL_ACCESS') == 'true':
        return "0.0.0.0"  # Explicitly allowed external access
    
    return "127.0.0.1"  # Default to localhost only for security

if __name__ == "__main__":
    import os
    
    # Security-aware configuration
    host = get_host()
    port = int(os.getenv('FLASK_PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting Flask app on {host}:{port} (debug={debug})")
    app.run(host=host, port=port, debug=debug)
