import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/equipamento.dart';
import '../models/manutencao.dart';

/// Camada de acesso ao banco de dados local (SQLite).
/// Toda a persistência do app passa por aqui — funciona 100% offline.
///
/// Padrão Singleton: existe apenas uma instância/conexão de banco
/// durante todo o ciclo de vida do app.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String tabelaEquipamentos = 'equipamentos';
  static const String tabelaManutencoes = 'manutencoes';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'c07l_manutencao.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tabelaEquipamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        categoria TEXT NOT NULL,
        patrimonio TEXT NOT NULL,
        valorAtual REAL NOT NULL,
        proximaManutencao REAL NOT NULL,
        intervaloManutencao REAL NOT NULL,
        ultimaAtualizacao TEXT NOT NULL,
        fotoPath TEXT,
        observacoes TEXT,
        alertasConfigurados TEXT NOT NULL,
        ultimoNivelAlertaNotificado INTEGER NOT NULL DEFAULT -1
      )
    ''');

    await db.execute('''
      CREATE TABLE $tabelaManutencoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipamentoId INTEGER NOT NULL,
        data TEXT NOT NULL,
        valorNoMomento REAL NOT NULL,
        pecasTrocadas TEXT,
        custo REAL DEFAULT 0,
        observacoes TEXT,
        fotos TEXT,
        FOREIGN KEY (equipamentoId) REFERENCES $tabelaEquipamentos (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_manutencao_equipamento ON $tabelaManutencoes (equipamentoId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reservado para futuras migrações de schema (novas colunas, etc.)
  }

  // ---------------------------------------------------------------------
  // CRUD — Equipamentos
  // ---------------------------------------------------------------------

  Future<int> inserirEquipamento(Equipamento equipamento) async {
    final db = await database;
    return await db.insert(tabelaEquipamentos, equipamento.toMap()
      ..remove('id'));
  }

  Future<int> atualizarEquipamento(Equipamento equipamento) async {
    final db = await database;
    return await db.update(
      tabelaEquipamentos,
      equipamento.toMap(),
      where: 'id = ?',
      whereArgs: [equipamento.id],
    );
  }

  Future<int> excluirEquipamento(int id) async {
    final db = await database;
    // Remove também o histórico de manutenções associado.
    await db.delete(tabelaManutencoes, where: 'equipamentoId = ?', whereArgs: [id]);
    return await db.delete(tabelaEquipamentos, where: 'id = ?', whereArgs: [id]);
  }

  Future<Equipamento?> buscarEquipamentoPorId(int id) async {
    final db = await database;
    final resultado = await db.query(
      tabelaEquipamentos,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Equipamento.fromMap(resultado.first);
  }

  Future<List<Equipamento>> listarEquipamentos({
    String? termoBusca,
    CategoriaEquipamento? categoria,
  }) async {
    final db = await database;
    String? where;
    List<Object?> whereArgs = [];

    final condicoes = <String>[];
    if (termoBusca != null && termoBusca.trim().isNotEmpty) {
      condicoes.add('(nome LIKE ? OR patrimonio LIKE ?)');
      whereArgs.addAll(['%$termoBusca%', '%$termoBusca%']);
    }
    if (categoria != null) {
      condicoes.add('categoria = ?');
      whereArgs.add(categoria.name);
    }
    if (condicoes.isNotEmpty) where = condicoes.join(' AND ');

    final resultado = await db.query(
      tabelaEquipamentos,
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return resultado.map((e) => Equipamento.fromMap(e)).toList();
  }

  // ---------------------------------------------------------------------
  // CRUD — Manutenções (histórico)
  // ---------------------------------------------------------------------

  Future<int> inserirManutencao(Manutencao manutencao) async {
    final db = await database;
    return await db.insert(tabelaManutencoes, manutencao.toMap()..remove('id'));
  }

  Future<int> atualizarManutencao(Manutencao manutencao) async {
    final db = await database;
    return await db.update(
      tabelaManutencoes,
      manutencao.toMap(),
      where: 'id = ?',
      whereArgs: [manutencao.id],
    );
  }

  Future<int> excluirManutencao(int id) async {
    final db = await database;
    return await db.delete(tabelaManutencoes, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Manutencao>> listarManutencoesPorEquipamento(int equipamentoId) async {
    final db = await database;
    final resultado = await db.query(
      tabelaManutencoes,
      where: 'equipamentoId = ?',
      whereArgs: [equipamentoId],
      orderBy: 'data DESC',
    );
    return resultado.map((e) => Manutencao.fromMap(e)).toList();
  }

  Future<List<Manutencao>> listarTodasManutencoes() async {
    final db = await database;
    final resultado = await db.query(tabelaManutencoes, orderBy: 'data DESC');
    return resultado.map((e) => Manutencao.fromMap(e)).toList();
  }

  // ---------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------

  /// Fecha a conexão (usado, por exemplo, antes de restaurar um backup).
  Future<void> fechar() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Apaga todos os dados (usado antes de uma importação completa).
  Future<void> limparTudo() async {
    final db = await database;
    await db.delete(tabelaManutencoes);
    await db.delete(tabelaEquipamentos);
  }
}
