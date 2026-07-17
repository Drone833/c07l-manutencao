import 'dart:convert';

/// Registro de uma manutenção realizada em um equipamento.
/// Compõe o histórico exibido na tela de detalhes do equipamento.
class Manutencao {
  final int? id;
  final int equipamentoId;
  DateTime data;
  double valorNoMomento; // horímetro/km/horas de voo no momento da manutenção
  String pecasTrocadas;
  double custo;
  String observacoes;
  List<String> fotos; // caminhos locais das fotos anexadas

  Manutencao({
    this.id,
    required this.equipamentoId,
    required this.data,
    required this.valorNoMomento,
    this.pecasTrocadas = '',
    this.custo = 0,
    this.observacoes = '',
    List<String>? fotos,
  }) : fotos = fotos ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipamentoId': equipamentoId,
      'data': data.toIso8601String(),
      'valorNoMomento': valorNoMomento,
      'pecasTrocadas': pecasTrocadas,
      'custo': custo,
      'observacoes': observacoes,
      'fotos': jsonEncode(fotos),
    };
  }

  factory Manutencao.fromMap(Map<String, dynamic> map) {
    return Manutencao(
      id: map['id'] as int?,
      equipamentoId: map['equipamentoId'] as int,
      data: DateTime.parse(map['data'] as String),
      valorNoMomento: (map['valorNoMomento'] as num).toDouble(),
      pecasTrocadas: map['pecasTrocadas'] as String? ?? '',
      custo: (map['custo'] as num?)?.toDouble() ?? 0,
      observacoes: map['observacoes'] as String? ?? '',
      fotos: map['fotos'] != null
          ? (jsonDecode(map['fotos'] as String) as List).cast<String>()
          : [],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Manutencao.fromJson(Map<String, dynamic> json) =>
      Manutencao.fromMap(json);
}
