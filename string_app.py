import boto3
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from typing import Dict, Any
from mangum import Mangum

TABLE_NAME = 'string-table'
KEY_NAME = 'string-key'
MAIN_KEY = 'main'
VALUE_NAME = 'string-value'
POST_PARAM = 'saved-string'

string_app = FastAPI()

@string_app.get('/')
async def root():
    db_response = client.get_item(TableName=TABLE_NAME, Key={KEY_NAME: {'S': MAIN_KEY}})
    html_response = f'<h1>The saved string is {db_response["Item"][VALUE_NAME]["S"]}</h1>'
    return HTMLResponse(html_response)

@string_app.put('/set_string')
async def set_string(body: Dict[Any, Any]):
    db_response = client.put_item(
        TableName=TABLE_NAME,
        Item={KEY_NAME: {'S': MAIN_KEY}, VALUE_NAME: {'S': body[POST_PARAM]}})
    return body

client = boto3.client('dynamodb')
handler = Mangum(string_app, lifespan='off')
