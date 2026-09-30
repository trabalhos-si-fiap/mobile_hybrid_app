// Lido pelo ng serve. API_URL aponta para a API dentro do Compose (http://api:8080);
// fora dele, o padrão é a API publicada no host.
const target = process.env.API_URL ?? 'http://localhost:8080';

export default {
  '/api': {
    target,
    secure: false,
    changeOrigin: true
  }
};
