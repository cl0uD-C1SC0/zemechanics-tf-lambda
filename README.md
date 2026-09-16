# Terraform

Passo a passo para configurar a AWS e aplicar a infraestrutura utilizando Terraform.

## 01. Configurar a AWS

Configure suas credenciais da AWS:

```bash
aws configure
```

Informe:

```text
AWS Access Key ID: <SUA_ACCESS_KEY>
AWS Secret Access Key: <SUA_SECRET_KEY>
Default region name: us-east-1
Default output format: json
```

Valide a configuração:

```bash
aws sts get-caller-identity
```

---

## 02. Inicializar o Terraform

Acesse o diretório onde estão os arquivos `.tf`:

```bash
cd terraform
```

Inicialize o Terraform:

```bash
terraform init
```

Valide a configuração:

```bash
terraform validate
```

---

## 03. Aplicar o Terraform

Visualize as alterações que serão realizadas:

```bash
terraform plan
```

Aplique a infraestrutura:

```bash
terraform apply
```

Confirme digitando:

```text
yes
```

Após a execução, o Terraform criará os recursos definidos nos arquivos `.tf`.

---

## Comandos úteis

Verifique o estado da infraestrutura:

```bash
terraform show
```

Liste os recursos criados:

```bash
terraform state list
```

Para destruir a infraestrutura:

```bash
terraform destroy
```
