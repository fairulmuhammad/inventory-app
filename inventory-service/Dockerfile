# Gunakan image Python sebagai base
FROM python:3.10-slim

# Set workdir
WORKDIR /app

# Salin file aplikasi
COPY . .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port dan jalankan aplikasi
EXPOSE 5000
CMD ["python", "app.py"]
