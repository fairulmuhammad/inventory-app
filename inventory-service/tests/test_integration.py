import pytest
import requests
import time
import subprocess
import signal
import os
from threading import Thread

class TestIntegration:
    """Integration tests for the inventory service"""
    
    @pytest.fixture(scope="class")
    def running_app(self):
        """Start the Flask app for integration testing"""
        # Start the app in a separate process
        proc = subprocess.Popen(
            ["python", "app.py"],
            cwd="./",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # Wait for the app to start
        time.sleep(2)
        
        yield "http://localhost:5000"
        
        # Clean up
        proc.terminate()
        proc.wait()

    def test_full_crud_workflow(self, running_app):
        """Test complete CRUD workflow"""
        base_url = running_app
        
        # Test health check
        response = requests.get(f"{base_url}/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
        
        # Test getting all items (initial state)
        response = requests.get(f"{base_url}/items")
        assert response.status_code == 200
        initial_count = response.json()["count"]
        
        # Test adding a new item
        new_item = {"name": "Integration Test Item", "stock": 50}
        response = requests.post(f"{base_url}/items", json=new_item)
        assert response.status_code == 201
        added_item = response.json()["item"]
        item_id = added_item["id"]
        
        # Verify item was added
        response = requests.get(f"{base_url}/items")
        assert response.status_code == 200
        assert response.json()["count"] == initial_count + 1
        
        # Test getting specific item
        response = requests.get(f"{base_url}/items/{item_id}")
        assert response.status_code == 200
        assert response.json()["name"] == "Integration Test Item"
        
        # Test updating the item
        updated_data = {"name": "Updated Integration Item", "stock": 75}
        response = requests.put(f"{base_url}/items/{item_id}", json=updated_data)
        assert response.status_code == 200
        assert response.json()["item"]["name"] == "Updated Integration Item"
        
        # Test deleting the item
        response = requests.delete(f"{base_url}/items/{item_id}")
        assert response.status_code == 200
        
        # Verify item was deleted
        response = requests.get(f"{base_url}/items/{item_id}")
        assert response.status_code == 404

    def test_api_error_handling(self, running_app):
        """Test API error handling"""
        base_url = running_app
        
        # Test invalid item data
        invalid_item = {"name": "", "stock": -1}
        response = requests.post(f"{base_url}/items", json=invalid_item)
        assert response.status_code == 400
        
        # Test non-existent item
        response = requests.get(f"{base_url}/items/99999")
        assert response.status_code == 404
        
        # Test updating non-existent item
        response = requests.put(f"{base_url}/items/99999", json={"name": "Test", "stock": 10})
        assert response.status_code == 404
        
        # Test deleting non-existent item
        response = requests.delete(f"{base_url}/items/99999")
        assert response.status_code == 404

if __name__ == "__main__":
    pytest.main([__file__])
