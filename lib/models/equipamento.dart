import 'dart:convert';

/// Categorias de equipamento suportadas pelo app.
///
/// Cada categoria define automaticamente:
/// - a unidade de controle (horímetro, km ou horas de voo)
/// - os valores padrão de alerta (podem ser reconfigurados por equipamento)
enum CategoriaEquipamento {
  gerador,
  caminhonete,
  caminhaoMuc,
  drone,
}

extension CategoriaEquipamentoExt on CategoriaEquipamento {
  /// Nome amigável exibido na interface.
  String get label {
    switch (this) {
      case CategoriaEquipamento.gerador:
        return 'Gerador';
      case CategoriaEquipamento.caminhonete:
        return 'Caminhonete';
      case CategoriaEquipamento.caminhaoMuc:
        return 'Caminhão MUC';
      case CategoriaEquipamento.drone:
        return 'Drone';
    }
  }

  /// Unidade de medida usada para exibir os valores (h ou km).
  String get unidade {
    switch (this) {
      case CategoriaEquipamento.gerador:
        return 'h'; // horímetro
      case CategoriaEquipamento.drone:
        return 'h'; // horas de voo
      case CategoriaEquipamento.caminhonete:
      case CategoriaEquipamento.caminhaoMuc:
        return 'km';
    }
  }

  /// Rótulo do campo de controle (para labels de formulário).
  String get rotuloControle {
    switch (this) {
      case CategoriaEquipamento.gerador:
        return 'Horímetro';
      case CategoriaEquipamento.drone:
        return 'Horas de voo';
      case CategoriaEquipamento.caminhonete:
      case CategoriaEquipamento.caminhaoMuc:
        return 'Quilometragem';
    }
  }

  /// Valores padrão de alerta (do menos crítico para o mais crítico),
  /// em unidades restantes até a manutenção.
  /// Estes valores são usados apenas como sugestão inicial ao cadastrar
  /// um novo equipamento; cada equipamento pode ter os seus próprios.
  List<double> get alertasPadrao {
    switch (this) {
      case CategoriaEquipamento.gerador:
        return [100, 50, 20, 10];
      case CategoriaEquipamento.drone:
        return [10, 5, 2, 1];
      case CategoriaEquipamento.caminhonete:
      case CategoriaEquipamento.caminhaoMuc:
        return [1000, 500, 100];
    }
  }

  /// Intervalo de manutenção padrão sugerido (unidade da categoria).
  double get intervaloPadrao {
    switch (this) {
      case CategoriaEquipamento.gerador:
        return 250; // ex.: manutenção a cada 250h
      case CategoriaEquipamento.drone:
        return 50; // ex.: manutenção a cada 50h de voo
      case CategoriaEquipamento.caminhonete:
      case CategoriaEquipamento.caminhaoMuc:
        return 10000; // ex.: manutenção a cada 10.000 km
    }
  }

  static CategoriaEquipamento fromString(String value) {
    return CategoriaEquipamento.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoriaEquipamento.gerador,
    );
  }
}

/// Situação atual do equipamento em relação à manutenção.
enum StatusManutencao { verde, amarelo, laranja, vermelho }

extension StatusManutencaoExt on StatusManutencao {
  String get label {
    switch (this) {
      case StatusManutencao.verde:
        return 'Em dia';
      case StatusManutencao.amarelo:
        return 'Atenção';
      case StatusManutencao.laranja:
        return 'Próximo da manutenção';
      case StatusManutencao.vermelho:
        return 'Manutenção vencida';
    }
  }
}

/// Modelo principal de um equipamento cadastrado.
class Equipamento {
  final int? id;
  String nome;
  CategoriaEquipamento categoria;
  String patrimonio; // Número de patrimônio / identificação
  double valorAtual; // horímetro, km ou horas de voo atuais
  double proximaManutencao; // valor absoluto em que vence a manutenção
  double intervaloManutencao; // intervalo configurável (usado para calcular a próxima)
  DateTime ultimaAtualizacao;
  String? fotoPath; // caminho local da foto do equipamento
  String observacoes;

  /// Lista de valores "restantes" que disparam alertas, do menos crítico
  /// para o mais crítico. Ex. gerador: [100, 50, 20, 10].
  List<double> alertasConfigurados;

  /// Guarda o menor nível de alerta já notificado para este ciclo de
  /// manutenção, evitando notificações repetidas para o mesmo limiar.
  int ultimoNivelAlertaNotificado;

  Equipamento({
    this.id,
    required this.nome,
    required this.categoria,
    required this.patrimonio,
    required this.valorAtual,
    required this.proximaManutencao,
    required this.intervaloManutencao,
    required this.ultimaAtualizacao,
    this.fotoPath,
    this.observacoes = '',
    List<double>? alertasConfigurados,
    this.ultimoNivelAlertaNotificado = -1,
  }) : alertasConfigurados =
            alertasConfigurados ?? categoria.alertasPadrao;

  /// Quanto falta (na unidade da categoria) para a próxima manutenção.
  /// Valor negativo indica manutenção vencida.
  double get restante => proximaManutencao - valorAtual;

  /// Calcula o status atual (cor) com base no valor restante e nos
  /// limiares de alerta configurados para este equipamento.
  ///
  /// Regra geral (independe da categoria, pois trabalha só com "restante"):
  /// - restante <= 0                      -> vermelho (vencida)
  /// - restante <= menor limiar            -> vermelho (crítico)
  /// - restante <= 2º maior limiar         -> laranja
  /// - restante <= maior limiar            -> amarelo
  /// - restante > maior limiar             -> verde
  StatusManutencao get status {
    if (restante <= 0) return StatusManutencao.vermelho;

    final limiares = List<double>.from(alertasConfigurados)
      ..sort((a, b) => b.compareTo(a)); // decrescente

    if (limiares.isEmpty) {
      // Sem alertas configurados: só diferencia vencido/em dia.
      return StatusManutencao.verde;
    }

    final maior = limiares.first;
    final critico = limiares.last;
    final segundo = limiares.length > 1 ? limiares[1] : critico;

    if (restante > maior) return StatusManutencao.verde;
    if (restante > segundo) return StatusManutencao.amarelo;
    if (restante > critico) return StatusManutencao.laranja;
    return StatusManutencao.vermelho;
  }

  /// Retorna o índice do limiar de alerta mais crítico já atingido
  /// pelo valor restante atual (-1 = nenhum atingido / tudo em dia).
  /// Usado para saber se é preciso disparar uma nova notificação.
  int get nivelAlertaAtual {
    final limiares = List<double>.from(alertasConfigurados)
      ..sort((a, b) => b.compareTo(a));
    for (int i = 0; i < limiares.length; i++) {
      if (restante <= limiares[i]) return i;
    }
    return -1;
  }

  Equipamento copyWith({
    int? id,
    String? nome,
    CategoriaEquipamento? categoria,
    String? patrimonio,
    double? valorAtual,
    double? proximaManutencao,
    double? intervaloManutencao,
    DateTime? ultimaAtualizacao,
    String? fotoPath,
    String? observacoes,
    List<double>? alertasConfigurados,
    int? ultimoNivelAlertaNotificado,
  }) {
    return Equipamento(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      patrimonio: patrimonio ?? this.patrimonio,
      valorAtual: valorAtual ?? this.valorAtual,
      proximaManutencao: proximaManutencao ?? this.proximaManutencao,
      intervaloManutencao: intervaloManutencao ?? this.intervaloManutencao,
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
      fotoPath: fotoPath ?? this.fotoPath,
      observacoes: observacoes ?? this.observacoes,
      alertasConfigurados: alertasConfigurados ?? this.alertasConfigurados,
      ultimoNivelAlertaNotificado:
          ultimoNivelAlertaNotificado ?? this.ultimoNivelAlertaNotificado,
    );
  }

  /// Converte para Map (persistência no SQLite).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria.name,
      'patrimonio': patrimonio,
      'valorAtual': valorAtual,
      'proximaManutencao': proximaManutencao,
      'intervaloManutencao': intervaloManutencao,
      'ultimaAtualizacao': ultimaAtualizacao.toIso8601String(),
      'fotoPath': fotoPath,
      'observacoes': observacoes,
      'alertasConfigurados': jsonEncode(alertasConfigurados),
      'ultimoNivelAlertaNotificado': ultimoNivelAlertaNotificado,
    };
  }

  factory Equipamento.fromMap(Map<String, dynamic> map) {
    return Equipamento(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      categoria: CategoriaEquipamentoExt.fromString(map['categoria'] as String),
      patrimonio: map['patrimonio'] as String,
      valorAtual: (map['valorAtual'] as num).toDouble(),
      proximaManutencao: (map['proximaManutencao'] as num).toDouble(),
      intervaloManutencao: (map['intervaloManutencao'] as num).toDouble(),
      ultimaAtualizacao: DateTime.parse(map['ultimaAtualizacao'] as String),
      fotoPath: map['fotoPath'] as String?,
      observacoes: map['observacoes'] as String? ?? '',
      alertasConfigurados: (jsonDecode(map['alertasConfigurados'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      ultimoNivelAlertaNotificado: map['ultimoNivelAlertaNotificado'] as int? ?? -1,
    );
  }

  /// Serializa para exportação (JSON legível, usado no export/import geral).
  Map<String, dynamic> toJson() => toMap();

  factory Equipamento.fromJson(Map<String, dynamic> json) =>
      Equipamento.fromMap(json);
}
