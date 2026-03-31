/// UFs brasileiras (nome + sigla) — ordem alfabética por nome.
class BrazilState {
  const BrazilState({required this.uf, required this.name});

  final String uf;
  final String name;

  String get label => '$name ($uf)';
}

const List<BrazilState> kBrazilStates = [
  BrazilState(uf: 'AC', name: 'Acre'),
  BrazilState(uf: 'AL', name: 'Alagoas'),
  BrazilState(uf: 'AP', name: 'Amapá'),
  BrazilState(uf: 'AM', name: 'Amazonas'),
  BrazilState(uf: 'BA', name: 'Bahia'),
  BrazilState(uf: 'CE', name: 'Ceará'),
  BrazilState(uf: 'DF', name: 'Distrito Federal'),
  BrazilState(uf: 'ES', name: 'Espírito Santo'),
  BrazilState(uf: 'GO', name: 'Goiás'),
  BrazilState(uf: 'MA', name: 'Maranhão'),
  BrazilState(uf: 'MT', name: 'Mato Grosso'),
  BrazilState(uf: 'MS', name: 'Mato Grosso do Sul'),
  BrazilState(uf: 'MG', name: 'Minas Gerais'),
  BrazilState(uf: 'PA', name: 'Pará'),
  BrazilState(uf: 'PB', name: 'Paraíba'),
  BrazilState(uf: 'PR', name: 'Paraná'),
  BrazilState(uf: 'PE', name: 'Pernambuco'),
  BrazilState(uf: 'PI', name: 'Piauí'),
  BrazilState(uf: 'RJ', name: 'Rio de Janeiro'),
  BrazilState(uf: 'RN', name: 'Rio Grande do Norte'),
  BrazilState(uf: 'RS', name: 'Rio Grande do Sul'),
  BrazilState(uf: 'RO', name: 'Rondônia'),
  BrazilState(uf: 'RR', name: 'Roraima'),
  BrazilState(uf: 'SC', name: 'Santa Catarina'),
  BrazilState(uf: 'SP', name: 'São Paulo'),
  BrazilState(uf: 'SE', name: 'Sergipe'),
  BrazilState(uf: 'TO', name: 'Tocantins'),
];

BrazilState? brazilStateByUf(String? uf) {
  if (uf == null || uf.isEmpty) return null;
  final u = uf.trim().toUpperCase();
  for (final s in kBrazilStates) {
    if (s.uf == u) return s;
  }
  return null;
}
