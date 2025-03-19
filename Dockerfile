FROM public.ecr.aws/lambda/python:3.13
ENV PYTHONUNBUFFERED=1

COPY requirements.txt ./
RUN pip3 install -r requirements.txt

COPY string_app.py ./
CMD [ "string_app.handler" ]
