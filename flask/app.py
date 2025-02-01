import time
import redis
import json
import os

from flask import Flask, redirect, url_for, request, Response, jsonify
app = Flask(__name__)

@app.route('/kv/<string:i>/<string:k>',defaults={'v': None}, methods=['POST', 'GET', 'DELETE', 'PUT'])
@app.route('/kv/<string:i>/<string:k>/<string:v>', methods=['POST', 'GET', 'DELETE', 'PUT'])
def kv(i:str,k:str,v:str):
    """
    Key value store to redis
    """
    status = 200
    m = request.method
    if v == None and m in ['POST', 'UPDATE']:
        return Response("{'id':'%s':{'Error':'value parameter is required','method':'%s'}}"%(i,m),
                        status   = 400,
                        mimetype = 'application/json')

    if v != None and m in ['GET', 'DELETE']:
        return Response("{'id':'%s':{'Error':'value parameter does not apply','method':'%s'}}"%(i,m),
                        status    = 400,
                        mimetype = 'application/json')

    if m == 'GET':
        rv = redis.get(k)
        if rv != None:
            rv = rv.decode("utf-8")
        else:
            status = 404
        resp = json.dumps({'request_id': i, 'request_key': k,
                          'response_value': rv, 'method': m})

    if m in ['POST', 'PUT']:
        redis.set(k, v)
        resp = json.dumps({'request_id': i, 'request_key': k,
                          'request_value': v, 'method': m})

    if m == 'DELETE':
        redis.delete(k)
        resp = json.dumps({'request_id': i, 'request_key': k,
                          'request_value': v, 'method': m})

    return Response(resp, status=200, mimetype='application/json')


if __name__ == '__main__':
    host = os.getenv('REDIS_HOST', '127.0.0.1')
    redis = redis.Redis(host=host, port=6379, db=0)
    can_ping = False
    while can_ping == False:
        try:
            can_ping = redis.ping()
        except Exception as ex:
            print('Cannot connect to redis')
            time.sleep(5)
    app.run(debug=True,host="0.0.0.0", port=8000)