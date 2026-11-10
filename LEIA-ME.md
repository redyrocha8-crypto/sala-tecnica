# Sala Técnica · EIBI Serra da Ibiapaba

Aplicativo web de gestão de demandas da Sala Técnica (Dois A Engenharia e Tecnologia).
Funciona no navegador do computador e do celular, com login pelo e-mail institucional @doisa.com.

- **Página:** GitHub Pages (grátis)
- **Banco de dados e login:** Supabase (plano grátis)
- **Regras de acesso:** aplicadas no próprio banco. Cada setor só edita as suas demandas, e só administradores gerenciam acessos.

---

## 1. Criar o banco (Supabase), cerca de 10 min

1. Entre em **https://supabase.com** → *Start your project* → crie a conta (pode usar o login do GitHub).
2. **New project**
   - Name: `sala-tecnica-eibi`
   - Database password: gere uma e guarde. Não será usada no aplicativo.
   - Region: **South America (São Paulo)**
3. Aguarde o projeto ficar pronto (cerca de 2 min).
4. Menu lateral **SQL Editor** → **New query** → cole todo o conteúdo de `supabase-schema.sql` → **Run**.
5. (Opcional) Para importar dados de uma planilha ou de outro ambiente, rode um script de carga no mesmo SQL Editor.
   Os dados da equipe não ficam neste repositório por privacidade.
6. Menu **Authentication → Sign In / Providers → Email**:
   - **Confirm email: DESATIVAR**. Assim a pessoa cria a senha e já entra, sem depender de e-mail de confirmação.
   - Minimum password length: `8`
7. Menu **Project Settings → API** (ou *Data API*): copie
   - **Project URL** (ex.: `https://abcdefgh.supabase.co`)
   - **anon public key** (chave longa que começa com `eyJ...`)

> A chave *anon* é pública por natureza: ela fica no navegador, e quem protege os dados são as regras do banco.
> **Nunca** use a chave `service_role` no aplicativo.

## 2. Configurar o aplicativo

Abra o arquivo `config.js` e cole os dois valores:

```js
window.SALA_TECNICA_CONFIG = {
  supabaseUrl: "https://abcdefgh.supabase.co",
  supabaseAnonKey: "eyJhbGciOi..."
};
```

## 3. Publicar (GitHub Pages), cerca de 5 min

1. Em **https://github.com** → **New repository** → nome `sala-tecnica` → **Public** → *Create*.
   (O GitHub Pages grátis exige repositório público. O código não contém dados nem senhas, apenas a chave pública.)
2. **Add file → Upload files** → arraste **todos os arquivos desta pasta** → *Commit changes*.
3. **Settings → Pages** → *Source: Deploy from a branch* → Branch **main** / **(root)** → *Save*.
4. Em 1 a 2 minutos o endereço fica disponível:
   **`https://SEU-USUARIO.github.io/sala-tecnica/`**

## 4. Primeiro acesso

1. Abra o endereço e entre com o e-mail do administrador. Como é o primeiro acesso, crie a senha.
2. Você é **Administrador**: a aba **Administração** mostra todos os acessos.
3. Envie o link para a equipe. Cada pessoa digita o próprio e-mail @doisa.com e cria a senha no primeiro acesso.

No celular, abra o link e use **"Adicionar à tela de início"**. O aplicativo abre como um app, com o ícone da Dois A.

---

## Perfis

| Perfil | Pode |
|---|---|
| **Administrador** | Gerenciar acessos e setores, redefinir senhas, editar todas as demandas |
| **Membro** | Cadastrar demandas; editar as do seu setor, as que criou e as que é responsável |
| **Leitura** | Apenas consultar demandas e indicadores |

## Administração do dia a dia

- **Nova pessoa:** Administração → *+ Novo acesso* (nome, e-mail, setor, perfil). Só e-mails cadastrados conseguem criar senha.
- **Esqueceu a senha:** Administração → *Editar* → *Redefinir senha*. A pessoa cria uma nova no próximo acesso.
- **Saiu da equipe:** desmarque *Acesso ativo*. Ela perde o acesso imediatamente, e o histórico é preservado.
- **Outro administrador:** basta mudar o perfil para *Administrador*.

## Manutenção e custos

- **Plano grátis do Supabase:** 500 MB de banco, muito acima do necessário. O projeto **pausa após 7 dias sem nenhum acesso**. Se acontecer, entre no painel do Supabase e clique em *Restore*. Com uso diário, isso não ocorre.
- **Backup:** Supabase → *Table Editor* → tabela `demandas` → *Export to CSV*.
- **Atualizar o aplicativo:** substitua o `index.html` no GitHub (*Add file → Upload files*). O GitHub Pages publica sozinho.

## Estrutura

```
index.html              aplicativo (interface completa)
config.js               endereço e chave pública do Supabase
manifest.webmanifest    instalação como app no celular
icone-192.png / -512    ícones
logo.png                logomarca
supabase-schema.sql     tabelas, regras de acesso e funções de login
```
