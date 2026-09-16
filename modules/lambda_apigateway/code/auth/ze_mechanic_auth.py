import os
import jwt


def lambda_handler(event, context):
    token = event.get("headers", {}).get("authorization", "")

    if not token.startswith("Bearer "):
        return {"isAuthorized": False}

    token = token.replace("Bearer ", "").strip()

    try:
        payload = jwt.decode(
            token,
            os.environ["JWT_SECRET"],
            algorithms=["HS256"],
        )
    except jwt.ExpiredSignatureError:
        print("Token expirado")
        return {"isAuthorized": False}
    except jwt.InvalidTokenError as e:
        print(f"Token inválido: {type(e).__name__}: {str(e)}")
        return {"isAuthorized": False}

    return {
        "isAuthorized": True,
        "context": {
            "customerId": str(payload["customer_id"]),
            "cpf": payload["cpf"],
        },
    }