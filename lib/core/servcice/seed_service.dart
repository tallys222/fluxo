import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  final FirebaseFirestore firestore;
  SeedService(this.firestore);

  Future<void> seedIfNeeded(String uid) async {
    final col = firestore.collection('users').doc(uid).collection('categories');

    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = firestore.batch();

    for (final c in _defaultCategories) {
      batch.set(col.doc(), {
        ...c,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static const _defaultCategories = [
    // ── DESPESAS ────────────────────────────────────────────────────────────
    {
      'name': 'Alimentação',
      'type': 'expense',
      'icon': '🍔',
      'color': '#FF6B6B',
    },
    {
      'name': 'Supermercado',
      'type': 'expense',
      'icon': '🛒',
      'color': '#FF8C42',
    },
    {
      'name': 'Restaurante',
      'type': 'expense',
      'icon': '🍽️',
      'color': '#FF6348',
    },
    {
      'name': 'Lanche',
      'type': 'expense',
      'icon': '☕',
      'color': '#C0763A',
    },
    {
      'name': 'Moradia',
      'type': 'expense',
      'icon': '🏠',
      'color': '#A29BFE',
    },
    {
      'name': 'Aluguel',
      'type': 'expense',
      'icon': '🔑',
      'color': '#6C5CE7',
    },
    {
      'name': 'Condomínio',
      'type': 'expense',
      'icon': '🏢',
      'color': '#8B7FE8',
    },
    {
      'name': 'Água',
      'type': 'expense',
      'icon': '💧',
      'color': '#4D96FF',
    },
    {
      'name': 'Energia Elétrica',
      'type': 'expense',
      'icon': '⚡',
      'color': '#FFC312',
    },
    {
      'name': 'Internet',
      'type': 'expense',
      'icon': '📶',
      'color': '#00B8D9',
    },
    {
      'name': 'Telefone',
      'type': 'expense',
      'icon': '📱',
      'color': '#0097A7',
    },
    {
      'name': 'Gás',
      'type': 'expense',
      'icon': '🔥',
      'color': '#FF7F50',
    },
    {
      'name': 'Transporte',
      'type': 'expense',
      'icon': '🚗',
      'color': '#74B9FF',
    },
    {
      'name': 'Combustível',
      'type': 'expense',
      'icon': '⛽',
      'color': '#636E72',
    },
    {
      'name': 'Uber / Táxi',
      'type': 'expense',
      'icon': '🚕',
      'color': '#FDCB6E',
    },
    {
      'name': 'Transporte Público',
      'type': 'expense',
      'icon': '🚌',
      'color': '#55A3FF',
    },
    {
      'name': 'Manutenção Veículo',
      'type': 'expense',
      'icon': '🔧',
      'color': '#B2BEC3',
    },
    {
      'name': 'Saúde',
      'type': 'expense',
      'icon': '💊',
      'color': '#00B894',
    },
    {
      'name': 'Plano de Saúde',
      'type': 'expense',
      'icon': '🏥',
      'color': '#00CEC9',
    },
    {
      'name': 'Farmácia',
      'type': 'expense',
      'icon': '💉',
      'color': '#55EFC4',
    },
    {
      'name': 'Dentista',
      'type': 'expense',
      'icon': '🦷',
      'color': '#81ECEC',
    },
    {
      'name': 'Academia',
      'type': 'expense',
      'icon': '🏋️',
      'color': '#E17055',
    },
    {
      'name': 'Educação',
      'type': 'expense',
      'icon': '📚',
      'color': '#6C5CE7',
    },
    {
      'name': 'Escola / Faculdade',
      'type': 'expense',
      'icon': '🎓',
      'color': '#A29BFE',
    },
    {
      'name': 'Cursos',
      'type': 'expense',
      'icon': '💻',
      'color': '#74B9FF',
    },
    {
      'name': 'Material Escolar',
      'type': 'expense',
      'icon': '✏️',
      'color': '#FDCB6E',
    },
    {
      'name': 'Lazer',
      'type': 'expense',
      'icon': '🎮',
      'color': '#FD79A8',
    },
    {
      'name': 'Streaming',
      'type': 'expense',
      'icon': '🎬',
      'color': '#E84393',
    },
    {
      'name': 'Viagem',
      'type': 'expense',
      'icon': '✈️',
      'color': '#00CEC9',
    },
    {
      'name': 'Hospedagem',
      'type': 'expense',
      'icon': '🏨',
      'color': '#55A3FF',
    },
    {
      'name': 'Vestuário',
      'type': 'expense',
      'icon': '👕',
      'color': '#A29BFE',
    },
    {
      'name': 'Calçados',
      'type': 'expense',
      'icon': '👟',
      'color': '#6C5CE7',
    },
    {
      'name': 'Beleza',
      'type': 'expense',
      'icon': '💄',
      'color': '#FD79A8',
    },
    {
      'name': 'Cuidados Pessoais',
      'type': 'expense',
      'icon': '🧴',
      'color': '#E84393',
    },
    {
      'name': 'Pets',
      'type': 'expense',
      'icon': '🐾',
      'color': '#A29BFE',
    },
    {
      'name': 'Compras Online',
      'type': 'expense',
      'icon': '📦',
      'color': '#FF7F50',
    },
    {
      'name': 'Eletrônicos',
      'type': 'expense',
      'icon': '🖥️',
      'color': '#636E72',
    },
    {
      'name': 'Casa / Decoração',
      'type': 'expense',
      'icon': '🛋️',
      'color': '#B7950B',
    },
    {
      'name': 'Impostos',
      'type': 'expense',
      'icon': '📄',
      'color': '#7F8C8D',
    },
    {
      'name': 'IPVA',
      'type': 'expense',
      'icon': '🏛️',
      'color': '#95A5A6',
    },
    {
      'name': 'IPTU',
      'type': 'expense',
      'icon': '🏛️',
      'color': '#95A5A6',
    },
    {
      'name': 'Cartão de Crédito',
      'type': 'expense',
      'icon': '💳',
      'color': '#2C3E50',
    },
    {
      'name': 'Empréstimo',
      'type': 'expense',
      'icon': '🏦',
      'color': '#E74C3C',
    },
    {
      'name': 'Seguros',
      'type': 'expense',
      'icon': '🛡️',
      'color': '#34495E',
    },
    {
      'name': 'Doações',
      'type': 'expense',
      'icon': '🤝',
      'color': '#27AE60',
    },
    {
      'name': 'Outros',
      'type': 'expense',
      'icon': '📌',
      'color': '#B2BEC3',
    },

    // ── RECEITAS ────────────────────────────────────────────────────────────
    {
      'name': 'Salário',
      'type': 'income',
      'icon': '💰',
      'color': '#00B894',
    },
    {
      'name': 'Freelance',
      'type': 'income',
      'icon': '💼',
      'color': '#00CEC9',
    },
    {
      'name': '13º Salário',
      'type': 'income',
      'icon': '🎁',
      'color': '#55EFC4',
    },
    {
      'name': 'Férias',
      'type': 'income',
      'icon': '🏖️',
      'color': '#FDCB6E',
    },
    {
      'name': 'Bônus',
      'type': 'income',
      'icon': '🏆',
      'color': '#F9CA24',
    },
    {
      'name': 'Investimentos',
      'type': 'income',
      'icon': '📈',
      'color': '#6AB04C',
    },
    {
      'name': 'Aluguel Recebido',
      'type': 'income',
      'icon': '🏠',
      'color': '#A29BFE',
    },
    {
      'name': 'Venda',
      'type': 'income',
      'icon': '🛍️',
      'color': '#FF8C42',
    },
    {
      'name': 'Reembolso',
      'type': 'income',
      'icon': '↩️',
      'color': '#74B9FF',
    },
    {
      'name': 'Presente',
      'type': 'income',
      'icon': '🎀',
      'color': '#FD79A8',
    },
    {
      'name': 'Outros',
      'type': 'income',
      'icon': '💵',
      'color': '#B2BEC3',
    },
  ];
}