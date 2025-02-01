FROM python:alpine

COPY app.py /app.py
RUN pip install flask redis
EXPOSE 8000

CMD ["python", "/app.py"]