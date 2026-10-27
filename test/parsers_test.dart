import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/recognition/plant_id_parser.dart';
import 'package:leafy/data/recognition/plantnet_parser.dart';

void main() {
  test('Plant.id identification', () {
    final r = parsePlantIdIdentification({
      'result': {
        'is_plant': {'probability': 0.99, 'binary': true},
        'classification': {
          'suggestions': [
            {
              'name': 'Monstera deliciosa',
              'probability': 0.93,
              'similar_images': [
                {'url': 'https://example.com/a.jpg'},
              ],
              'details': {
                'common_names': ['монстера деликатесная', 'swiss cheese plant'],
                'taxonomy': {'family': 'Araceae', 'genus': 'Monstera'},
                'description': {'value': 'Лиана из тропиков.'},
                'image': {'value': 'https://example.com/main.jpg'},
                'watering': {'min': 2, 'max': 2},
                'best_light_condition': 'Яркий рассеянный свет',
                'toxicity': 'Ядовита для кошек',
                'url': 'https://ru.wikipedia.org/wiki/Монстера',
              },
            },
            {'name': 'Philodendron', 'probability': 0.03, 'details': null},
          ],
        },
      },
    });
    expect(r.provider, 'Plant.id');
    expect(r.candidates, hasLength(2));
    final top = r.candidates.first;
    expect(top.displayName, 'Монстера деликатесная');
    expect(top.family, 'Araceae');
    expect(top.imageUrls, ['https://example.com/main.jpg', 'https://example.com/a.jpg']);
    expect(top.description, 'Лиана из тропиков.');
    expect(top.suggestedWateringDays, 7);
    expect(r.candidates[1].commonNames, isEmpty);
  });

  test('Plant.id health assessment', () {
    final h = parsePlantIdHealth({
      'result': {
        'is_healthy': {'probability': 0.12, 'binary': false},
        'disease': {
          'suggestions': [
            {
              'name': 'water excess or uneven watering',
              'probability': 0.71,
              'details': {
                'local_name': 'переувлажнение',
                'treatment': {
                  'prevention': ['Поливать после подсыхания почвы'],
                  'biological': [],
                },
              },
            },
          ],
        },
      },
    });
    expect(h.isHealthy, isFalse);
    expect(h.diseases.single.name, 'переувлажнение');
    expect(h.diseases.single.prevention, ['Поливать после подсыхания почвы']);
    expect(h.diseases.single.chemical, isEmpty);
  });

  test('Pl@ntNet identify', () {
    final r = parsePlantNet({
      'results': [
        {
          'score': 0.81,
          'species': {
            'scientificNameWithoutAuthor': 'Ficus elastica',
            'genus': {'scientificNameWithoutAuthor': 'Ficus'},
            'family': {'scientificNameWithoutAuthor': 'Moraceae'},
            'commonNames': ['Rubber plant'],
          },
          'gbif': {'id': '5361900'},
          'images': [
            {
              'url': {'o': 'https://x/o.jpg', 'm': 'https://x/m.jpg', 's': 'https://x/s.jpg'},
            },
          ],
        },
      ],
    });
    final c = r.candidates.single;
    expect(c.scientificName, 'Ficus elastica');
    expect(c.family, 'Moraceae');
    expect(c.gbifId, 5361900);
    expect(c.imageUrls, ['https://x/m.jpg']);
    expect(c.infoUrl, 'https://www.gbif.org/species/5361900');
    expect(c.wateringLevel, isNull);
  });

  test('Pl@ntNet: пустой ответ', () {
    expect(parsePlantNet({'results': []}).candidates, isEmpty);
  });
}
