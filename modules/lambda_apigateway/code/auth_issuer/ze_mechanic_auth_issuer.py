import os
import json
import datetime
import pymysql
import jwt


def validar_cpf(cpf: str) -> bool:
    cpf_limpo = "".join(filter(str.isdigit, cpf))

    if len(cpf_limpo) != 11 or cpf_limpo == cpf_limpo[0] * 11:
        return False

    for i in range(9, 11):
        soma = sum(int(cpf_limpo[num]) * ((i + 1) - num) for num in range(0, i))
        digito = ((soma * 10) % 11) % 10
        if digito != int(cpf_limpo[i]):
            return False

    return True

def buscar_cliente_por_cpf(cpf_formatado: str):
    connection = pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, nome, cpf FROM clientes WHERE cpf = %s",
                (cpf_formatado,),
            )
            return cursor.fetchone()
    finally:
        connection.close()


def gerar_jwt(cliente: dict) -> str:
    payload = {
        "customer_id": cliente["id"],
        "cpf": cliente["cpf"],
        "iat": datetime.datetime.utcnow(),
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=2),
    }
    return jwt.encode(payload, os.environ["JWT_SECRET"], algorithm="HS256")


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        cpf = body.get("cpf", "")
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"detail": "Body inválido, esperado JSON"}),
        }

    if not validar_cpf(cpf):
        return {
            "statusCode": 400,
            "body": json.dumps({"detail": "CPF inválido"}),
        }

    cpf_limpo = "".join(filter(str.isdigit, cpf))

    try:
        cliente = buscar_cliente_por_cpf(cpf_limpo)
    except Exception as e:
        print(f"ERROR conectando ao banco: {type(e).__name__}: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"detail": "Erro ao consultar cliente"}),
        }

    if not cliente:
        return {
            "statusCode": 404,
            "body": json.dumps({"detail": "Cliente nao encontrado"}),
        }

    token = gerar_jwt(cliente)

    return {
        "statusCode": 200,
        "body": json.dumps({"token": token}),
    }