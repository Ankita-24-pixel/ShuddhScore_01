import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/family_member.dart';
import 'package:smooth_app/services/family_product_assessment.dart';
import 'package:smooth_app/services/groq_family_explanation.dart';

void main() {
  const FamilyProductAssessment assessment = FamilyProductAssessment(
    status: FamilySuitability.limitOrAvoid,
    reasons: <String>['High salt: 2 g per 100 g.'],
  );
  test('placeholder disables Groq and makes no request', () async {
    bool called = false;
    final MockClient client = MockClient((_) async {
      called = true;
      return http.Response('', 200);
    });
    const GroqFamilyExplanation service = GroqFamilyExplanation();
    expect(service.configured, isFalse);
    await expectLater(
      service.explain(FamilyAgeGroup.adult, assessment, client: client),
      throwsStateError,
    );
    expect(called, isFalse);
  });

  test(
    'request only sends age group and existing screening evidence',
    () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.host, 'api.groq.com');
        expect(request.headers['Authorization'], 'Bearer test-key');
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        final List<Object?> messages = body['messages'] as List<Object?>;
        final Map<String, dynamic> message =
            messages[1]! as Map<String, dynamic>;
        final Map<String, dynamic> evidence =
            jsonDecode(message['content'] as String) as Map<String, dynamic>;
        expect(
          evidence.keys,
          unorderedEquals(<String>['age_group', 'screening_result', 'reasons']),
        );
        expect(evidence['screening_result'], 'Limit or avoid');
        return http.Response(
          jsonEncode(<String, Object>{
            'choices': <Object>[
              <String, Object>{
                'message': <String, String>{
                  'content': 'Compare with a lower-salt option.',
                },
              },
            ],
          }),
          200,
        );
      });
      expect(
        await const GroqFamilyExplanation(
          apiKey: 'test-key',
        ).explain(FamilyAgeGroup.adult, assessment, client: client),
        'Compare with a lower-salt option.',
      );
      expect(assessment.status, FamilySuitability.limitOrAvoid);
    },
  );

  test(
    'API failures and malformed replies leave classification unchanged',
    () async {
      for (final http.Response response in <http.Response>[
        http.Response('rate limited', 429),
        http.Response('{}', 200),
        http.Response('{bad-json', 200),
        http.Response('{"choices":[{"message":{"content":""}}]}', 200),
      ]) {
        await expectLater(
          const GroqFamilyExplanation(apiKey: 'test-key').explain(
            FamilyAgeGroup.adult,
            assessment,
            client: MockClient((_) async => response),
          ),
          throwsA(isA<Object>()),
        );
        expect(assessment.status, FamilySuitability.limitOrAvoid);
      }
    },
  );

  test(
    'Groq request carries the selected product and supports reasoning model',
    () async {
      final MockClient client = MockClient((http.Request request) async {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'openai/gpt-oss-20b');
        expect(body['reasoning_effort'], 'low');
        final List<Object?> messages = body['messages'] as List<Object?>;
        final Map<String, dynamic> userMessage =
            messages[1]! as Map<String, dynamic>;
        final Map<String, dynamic> evidence =
            jsonDecode(userMessage['content'] as String)
                as Map<String, dynamic>;
        final Map<String, dynamic> product =
            evidence['product'] as Map<String, dynamic>;
        expect(product['barcode'], '222');
        expect(product['name'], 'Current product');
        expect(product['sugars_g'], 46);
        expect(evidence.containsKey('name'), isFalse);
        return http.Response(
          '{"choices":[{"message":{"content":"The label is high in sugar."}}]}',
          200,
        );
      });
      final Product product = Product(
        barcode: '222',
        productName: 'Current product',
        nutriments: Nutriments.empty()
          ..setValue(Nutrient.sugars, PerSize.oneHundredGrams, 46),
      );
      await const GroqFamilyExplanation(apiKey: 'test-key').explain(
        FamilyAgeGroup.adult,
        assessment,
        product: product,
        client: client,
      );
    },
  );

  test('model and rate-limit failures explain the actual problem', () async {
    for (final int status in <int>[401, 404, 429]) {
      await expectLater(
        const GroqFamilyExplanation(apiKey: 'test-key').explain(
          FamilyAgeGroup.adult,
          assessment,
          client: MockClient((_) async => http.Response('{}', status)),
        ),
        throwsA(
          isA<GroqExplanationException>().having(
            (GroqExplanationException error) => error.message,
            'message',
            contains(
              status == 404
                  ? 'model'
                  : status == 429
                  ? 'limit'
                  : 'API key',
            ),
          ),
        ),
      );
    }
  });
}
