# Use a base image with Python (adjust as needed)
FROM python:3.9-slim

# Install necessary dependencies
RUN pip install --no-cache-dir flask sentence-transformers datasets

# Set the working directory
WORKDIR /app

COPY question_to_embedding.py /app/question_to_embedding.py