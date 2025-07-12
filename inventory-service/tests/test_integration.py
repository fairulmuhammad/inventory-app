import pytest
import json
from app import app

class TestIntegration:
    """Integration tests for the inventory service"""
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client for integration testing"""
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client

    def test_full_crud_workflow(self, client):
        """Test complete CRUD workflow using test client"""
        # Test health check
        response = client.get("/health")
        assert response.status_code == 200
        assert response.get_json()["status"] == "healthy"
        
        # Test getting all items (initial state)
        response = client.get("/items")
        assert response.status_code == 200
        initial_count = response.get_json()["count"]
        
        # Test adding a new item
        new_item = {"name": "Integration Test Item", "stock": 50}
        response = client.post("/items", 
                             data=json.dumps(new_item),
                             content_type='application/json')
        assert response.status_code == 201
        added_item = response.get_json()["item"]
        item_id = added_item["id"]
        
        # Verify item count increased
        response = client.get("/items")
        assert response.status_code == 200
        assert response.get_json()["count"] == initial_count + 1
        
        # Test getting the specific item
        response = client.get(f"/items/{item_id}")
        assert response.status_code == 200
        item_data = response.get_json()
        assert item_data["name"] == "Integration Test Item"
        assert item_data["stock"] == 50
        
        # Test updating the item
        updated_data = {"name": "Updated Integration Item", "stock": 75}
        response = client.put(f"/items/{item_id}",
                            data=json.dumps(updated_data),
                            content_type='application/json')
        assert response.status_code == 200
        assert response.get_json()["item"]["name"] == "Updated Integration Item"
        assert response.get_json()["item"]["stock"] == 75
        
        # Test deleting the item
        response = client.delete(f"/items/{item_id}")
        assert response.status_code == 200
        
        # Verify item is deleted
        response = client.get(f"/items/{item_id}")
        assert response.status_code == 404
        
        # Verify item count returned to initial state
        response = client.get("/items")
        assert response.status_code == 200
        assert response.get_json()["count"] == initial_count

    def test_api_error_handling(self, client):
        """Test API error handling scenarios"""
        # Test missing fields
        response = client.post("/items",
                             data=json.dumps({"name": "Test"}),
                             content_type='application/json')
        assert response.status_code == 400
        
        # Test invalid stock value
        response = client.post("/items",
                             data=json.dumps({"name": "Test", "stock": -1}),
                             content_type='application/json')
        assert response.status_code == 400

    def test_metrics_endpoint(self, client):
        """Test that metrics endpoint is available"""
        response = client.get("/metrics")
        assert response.status_code == 200
        # Check if it contains Prometheus metrics format
        metrics_data = response.get_data(as_text=True)
        assert "# HELP" in metrics_data or "# TYPE" in metrics_data

if __name__ == "__main__":
    pytest.main([__file__])
