// Espera a API e o painel responderem antes dos testes. A primeira subida
// compila a API e cria o banco, e pode levar alguns minutos.
const targets = [`${process.env.API_URL}/openapi.yaml`, `${process.env.BASE_URL}/`];
const deadline = Date.now() + 15 * 60_000;

for (const url of targets) {
  for (;;) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        console.log(`pronto: ${url}`);
        break;
      }
    } catch {
      // ainda subindo
    }
    if (Date.now() > deadline) {
      console.error(`tempo esgotado esperando ${url}`);
      process.exit(1);
    }
    await new Promise(resolve => setTimeout(resolve, 3000));
  }
}
