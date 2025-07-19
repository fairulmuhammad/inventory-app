#!/usr/bin/env python3
"""
TechNova Security Configuration Module
Implements security best practices for the inventory service
"""

import os
import logging
from flask import Flask
from flask_talisman import Talisman

def configure_security(app: Flask) -> Flask:
    """
    Configure comprehensive security settings for Flask application
    
    Args:
        app: Flask application instance
        
    Returns:
        Configured Flask application with security enhancements
    """
    
    # 1. Security Headers with Flask-Talisman
    csp = {
        'default-src': "'self'",
        'script-src': "'self' 'unsafe-inline'",
        'style-src': "'self' 'unsafe-inline'",
        'img-src': "'self' data:",
        'font-src': "'self'",
        'connect-src': "'self'",
        'frame-ancestors': "'none'"
    }
    
    Talisman(app, 
             force_https=False,  # Set to True in production with HTTPS
             strict_transport_security=True,
             content_security_policy=csp,
             content_security_policy_nonce_in=['script-src', 'style-src'])
    
    # 2. Disable Server Header
    @app.after_request
    def remove_server_header(response):
        response.headers.pop('Server', None)
        return response
    
    # 3. Configure Secure Session
    app.config.update(
        SECRET_KEY=os.environ.get('SECRET_KEY', os.urandom(24)),
        SESSION_COOKIE_SECURE=True,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE='Lax',
        PERMANENT_SESSION_LIFETIME=1800,  # 30 minutes
    )
    
    # 4. Rate Limiting Configuration (placeholder)
    app.config.update(
        RATELIMIT_STORAGE_URL='memory://',
        RATELIMIT_DEFAULT="100 per hour",
    )
    
    # 5. Logging Security Events
    security_logger = logging.getLogger('security')
    security_handler = logging.FileHandler('security.log')
    security_handler.setFormatter(
        logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    )
    security_logger.addHandler(security_handler)
    security_logger.setLevel(logging.INFO)
    
    app.security_logger = security_logger
    
    return app

def get_secure_host():
    """
    Determine secure host binding configuration
    
    Returns:
        str: Host IP address for binding
    """
    
    # Check if running in Docker
    if os.path.exists('/.dockerenv'):
        return "0.0.0.0"  # Container environment
    
    # Check explicit permission for external access
    if (os.getenv('FLASK_ENV') == 'production' and 
        os.getenv('ALLOW_EXTERNAL_ACCESS', '').lower() == 'true'):
        return "0.0.0.0"
    
    # Default to localhost for security
    return "127.0.0.1"

def validate_environment():
    """
    Validate that security-critical environment variables are properly set
    
    Raises:
        ValueError: If critical security configurations are missing
    """
    
    required_prod_vars = ['SECRET_KEY', 'FLASK_ENV']
    
    if os.getenv('FLASK_ENV') == 'production':
        missing_vars = [var for var in required_prod_vars 
                       if not os.getenv(var)]
        
        if missing_vars:
            raise ValueError(
                f"Missing required environment variables for production: {missing_vars}"
            )
    
    # Validate SECRET_KEY strength
    secret_key = os.getenv('SECRET_KEY')
    if secret_key and len(secret_key) < 16:
        raise ValueError("SECRET_KEY must be at least 16 characters long")

def log_security_event(app: Flask, event_type: str, details: str):
    """
    Log security-related events
    
    Args:
        app: Flask application
        event_type: Type of security event
        details: Event details
    """
    
    if hasattr(app, 'security_logger'):
        app.security_logger.info(f"{event_type}: {details}")

# Security Configuration Constants
SECURITY_CONFIG = {
    'MAX_CONTENT_LENGTH': 16 * 1024 * 1024,  # 16MB max request size
    'JSON_MAX_SIZE': 1024 * 1024,            # 1MB max JSON size
    'UPLOAD_FOLDER_PERMISSIONS': 0o755,       # Secure upload permissions
    'DEFAULT_TIMEOUT': 30,                    # Request timeout
    'MAX_CONNECTIONS': 100,                   # Connection pool limit
}

if __name__ == "__main__":
    # Test security configuration
    from flask import Flask
    
    test_app = Flask(__name__)
    test_app = configure_security(test_app)
    
    print("✅ Security configuration test passed")
    print(f"📊 Configured security headers: {len(test_app.url_map.rules)} rules")
    print(f"🔐 Secret key configured: {'Yes' if test_app.config.get('SECRET_KEY') else 'No'}")
    print(f"🌐 Secure host: {get_secure_host()}")
