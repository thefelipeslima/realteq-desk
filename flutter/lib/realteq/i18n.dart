import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Idioma do programa. Português é o padrão; qualquer outro valor que não
/// seja "en" mostra português. A troca vale na hora porque todas as telas
/// leem o idioma a cada reconstrução.
bool get rtEn => bind.mainGetLocalOption(key: kCommConfKeyLang) == 'en';

/// Traduz um texto escrito em português. Em inglês procura no dicionário;
/// se não achar, devolve o próprio texto.
String tr(String pt) => rtEn ? (_en[pt] ?? pt) : pt;

String trAgo(int ts) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (d.inMinutes < 1) return rtEn ? 'just now' : 'agora';
  if (d.inMinutes < 60) {
    return rtEn ? '${d.inMinutes} min ago' : 'há ${d.inMinutes} min';
  }
  if (d.inHours < 24) return rtEn ? '${d.inHours} h ago' : 'há ${d.inHours} h';
  if (d.inDays == 1) return rtEn ? 'yesterday' : 'ontem';
  return rtEn ? '${d.inDays} days ago' : 'há ${d.inDays} dias';
}

const Map<String, String> _en = {
  'Início': 'Home',
  'Clientes': 'Clients',
  'Configurações': 'Settings',
  'Modo claro': 'Light mode',
  'Modo escuro': 'Dark mode',
  'Serviço parado': 'Service stopped',
  'Conectando...': 'Connecting...',
  'Sem conexão com o servidor': 'No connection to the server',
  'Serviço ativo': 'Service active',
  'Meu acesso': 'My access',
  'Copiar ID': 'Copy ID',
  'ID copiado': 'ID copied',
  'Copiar convite': 'Copy invite',
  'Convite copiado. Cole na conversa com o cliente.':
      'Invite copied. Paste it into your chat with the client.',
  'Senha temporária': 'Temporary password',
  'Copiar senha': 'Copy password',
  'Senha copiada': 'Password copied',
  'Gerar nova senha': 'Generate new password',
  'Instalar no computador': 'Install on this computer',
  'Conectar': 'Connect',
  'ID do computador remoto': 'Remote computer ID',
  'Clientes recentes': 'Recent clients',
  'Limpar tudo': 'Clear all',
  'Nenhum atendimento ainda.': 'No sessions yet.',
  'Tirar dos favoritos': 'Remove from favorites',
  'Favoritar': 'Add to favorites',
  'Editar nome e nota': 'Edit name and note',
  'Remover este cliente do histórico': 'Remove this client from history',
  'Cliente': 'Client',
  'Nome. Ex.: Maria (Recepção)': 'Name, e.g. Mary (Front desk)',
  'Nota. Ex.: impressora da sala 2': 'Note, e.g. printer in room 2',
  'Cancelar': 'Cancel',
  'Salvar': 'Save',
  'Todos os clientes': 'All clients',
  'Limpar histórico': 'Clear history',
  'Os clientes que você atender aparecem aqui,\ncom o nome que você der a eles.':
      'Clients you support appear here,\nwith the name you give them.',
  'Configurações protegidas': 'Protected settings',
  'Só o administrador pode alterar as configurações.\nDigite a senha para continuar.':
      'Only the administrator can change the settings.\nEnter the password to continue.',
  'Senha do administrador': 'Administrator password',
  'Senha incorreta': 'Incorrect password',
  'Entrar': 'Unlock',
  'Geral': 'General',
  'Idioma, tema e serviço': 'Language, theme and service',
  'Segurança': 'Security',
  'Senhas de acesso': 'Access passwords',
  'Servidor': 'Server',
  'Conexão com o servidor': 'Server connection',
  'Sobre': 'About',
  'Versão do programa': 'Program version',
  'Idioma': 'Language',
  'Português é o padrão': 'Portuguese is the default',
  'Tema': 'Theme',
  'Escuro': 'Dark',
  'Claro': 'Light',
  'Serviço de acesso': 'Access service',
  'Mantém este computador disponível para suporte':
      'Keeps this computer available for support',
  'Senhas aceitas': 'Accepted passwords',
  'Quais senhas liberam o acesso a este computador':
      'Which passwords grant access to this computer',
  'Ambas': 'Both',
  'Temporária': 'Temporary',
  'Mestra': 'Master',
  'Senha mestra': 'Master password',
  'Senha fixa para acessos diretos': 'Fixed password for direct access',
  'Alterar': 'Change',
  'Padrão': 'Default',
  'Configurar': 'Configure',
  'Suporte remoto da Realteq': 'Realteq remote support',
  'Aplicativo em desenvolvimento por Felipe Lima.':
      'App under development by Felipe Lima.',
  'Como você quer entrar?': 'How do you want to connect?',
  'Nome do cliente (opcional)': 'Client name (optional)',
  'Acesso direto': 'Direct access',
  'Usa a senha mestra. Entra sem o cliente aceitar.':
      'Uses the master password. Connects without the client accepting.',
  'Lembrete': 'Reminder',
  'Entendi, conectar': 'Got it, connect',
  'Aguardar o cliente': 'Wait for the client',
  'O cliente aceita no computador dele ou passa a senha.':
      'The client accepts on their computer or gives you the password.',
  'Criar atalho': 'Create shortcut',
  'Atalho criado na área de trabalho': 'Shortcut created on the desktop',
  'Atualizar': 'Update',
  'Atualizar instalação': 'Update installation',
  'A instalação está numa versão mais antiga.':
      'The installation is an older version.',
  'Você': 'You',
  'Conversa': 'Chat',
  'conectado': 'connected',
  'desconectado': 'disconnected',
  'Computador': 'Computer',
  'Definir senha mestra': 'Set master password',
  'Nova senha': 'New password',
  'Confirmação': 'Confirmation',
  'Remover': 'Remove',
};
