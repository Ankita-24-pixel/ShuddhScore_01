import 'package:flutter/material.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/family_member.dart';
import 'package:smooth_app/data_models/family_profiles.dart';
import 'package:smooth_app/pages/family/family_members_page.dart';
import 'package:smooth_app/services/family_product_assessment.dart';
import 'package:smooth_app/services/groq_family_explanation.dart';
import 'package:url_launcher/url_launcher.dart';

Color _color(FamilySuitability status) => switch (status) {
  FamilySuitability.suitable => const Color(0xFF176B36),
  FamilySuitability.limitOrAvoid => const Color(0xFFB3261E),
  FamilySuitability.unknown => const Color(0xFF545B64),
};

IconData _icon(FamilySuitability status) => switch (status) {
  FamilySuitability.suitable => Icons.check_circle_outline,
  FamilySuitability.limitOrAvoid => Icons.warning_amber_rounded,
  FamilySuitability.unknown => Icons.help_outline,
};

/// Compact per-person results for product search and history lists.
class FamilyProductChips extends StatelessWidget {
  const FamilyProductChips({
    required this.product,
    this.showLabelFacts = true,
    super.key,
  });
  final Product product;
  final bool showLabelFacts;

  @override
  Widget build(BuildContext context) {
    final List<FamilyMember> members =
        context.watch<FamilyProfiles?>()?.members ?? <FamilyMember>[];
    if (members.isEmpty ||
        (product.productType != null &&
            product.productType != ProductType.food)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showLabelFacts) ...<Widget>[
            _FamilyLabelFacts(product: product),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: members.map((FamilyMember member) {
              final FamilyProductAssessment assessment =
                  const FamilyProductAssessor().assess(product, member);
              final Color color = _color(assessment.status);
              return Semantics(
                label: '${member.name}, age ${member.age}: ${assessment.label}',
                child: Tooltip(
                  message:
                      '${member.name}: ${assessment.label}. ${assessment.reasons.first} Tap the product for all reasons.',
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _icon(assessment.status),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${member.name} · ${member.age}\n${assessment.label}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// The first product-detail section, with the saved members and their results.
class FamilyProductSummary extends StatelessWidget {
  const FamilyProductSummary({required this.product, super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final FamilyProfiles? profiles = context.watch<FamilyProfiles?>();
    if (profiles == null ||
        profiles.members.isEmpty ||
        (product.productType != null &&
            product.productType != ProductType.food)) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Family nutrition check',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Manage family',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openFamilyMembers(context),
                ),
              ],
            ),
            FamilyProductChips(product: product, showLabelFacts: false),
            const SizedBox(height: 12),
            const Text(
              'Green: no concern found · Red: limit or avoid · Grey: not enough information',
            ),
          ],
        ),
      ),
    );
  }
}

class FamilyProductCard extends StatelessWidget {
  const FamilyProductCard({required this.product, super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final FamilyProfiles? profiles = context.watch<FamilyProfiles?>();
    if (profiles == null) {
      return const SizedBox.shrink();
    }
    if (profiles.members.isEmpty) {
      return const FamilySetupPrompt();
    }
    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('For your family'),
            subtitle: const Text('A separate age-based check for each member'),
            trailing: IconButton(
              tooltip: 'Manage family',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openFamilyMembers(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _FamilyLabelFacts(product: product),
          ),
          for (final FamilyMember member in profiles.members)
            _MemberResult(product: product, member: member),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Green: no concern found in these checks. Red: limit or avoid. Grey: insufficient data. '
              'Age and label data cannot account for allergies, medical conditions, medicines or individual needs. '
              'Red describes a potential concern, not a prediction that this product will harm this person.',
            ),
          ),
          ExpansionTile(
            title: const Text('How these checks work'),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'We use the label’s ingredients, categories, and nutrients per 100 g (100 ml for drinks). '
                  'High-label thresholds: sugar >22.5 g (>11.25 g for drinks), salt >1.5 g, and saturated fat >5 g (>2.5 g for drinks). '
                  'Infants need a feeding-stage review. Children under 2 are checked for added sugar; children and teenagers for caffeine and alcohol. '
                  'Adult saturated-fat screening is not applied under 2. '
                  'Adult and older-adult explanations reflect the same label evidence; age alone does not establish a disease. '
                  'Portion size and the rest of the diet still matter.',
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.gov.uk/government/publications/front-of-pack-nutrition-labelling-guidance',
                  ),
                ),
                child: const Text('UK nutrition label guidance'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/foods-and-drinks-to-avoid-or-limit.html',
                  ),
                ),
                child: const Text('CDC: infant and toddler food guidance'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.healthychildren.org/English/healthy-living/nutrition/Pages/the-effects-of-caffeine-on-kids-a-parents-guide.aspx',
                  ),
                ),
                child: const Text('AAP: caffeine and young people'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberResult extends StatelessWidget {
  const _MemberResult({required this.product, required this.member});
  final Product product;
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final FamilyProductAssessment assessment = const FamilyProductAssessor()
        .assess(product, member);
    final Color color = _color(assessment.status);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey<String>('${product.barcode}-${member.id}-${member.age}'),
        leading: Icon(_icon(assessment.status), color: color),
        title: Text(
          '${member.name} · ${member.age} ${member.age == 1 ? 'year' : 'years'}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(member.ageGroup.label),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                assessment.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: <Widget>[
          ...assessment.reasons.map(
            (String reason) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(reason),
              ),
            ),
          ),
          if (const GroqFamilyExplanation().configured)
            _AiExplanation(
              key: ValueKey<String>(
                '${product.barcode}-${product.productName}-${member.age}-${assessment.reasons.join()}',
              ),
              ageGroup: member.ageGroup,
              assessment: assessment,
              product: product,
            ),
        ],
      ),
    );
  }
}

class _AiExplanation extends StatefulWidget {
  const _AiExplanation({
    required this.ageGroup,
    required this.assessment,
    required this.product,
    super.key,
  });
  final FamilyAgeGroup ageGroup;
  final FamilyProductAssessment assessment;
  final Product product;

  @override
  State<_AiExplanation> createState() => _AiExplanationState();
}

class _AiExplanationState extends State<_AiExplanation> {
  bool _loading = false;
  String? _text;
  String? _error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_text != null) ...<Widget>[
          Text(
            'AI-generated explanation',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(_text!),
        ] else
          TextButton.icon(
            onPressed: _loading ? null : _explain,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(_loading ? 'Explaining…' : 'Explain simply with AI'),
          ),
        if (_text == null)
          const Text(
            'Sends this product’s label data, age group and reasons to Groq. Your name and exact age stay on this device.',
          ),
        if (_error != null) Text(_error!),
      ],
    ),
  );

  Future<void> _explain() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String text = await const GroqFamilyExplanation().explain(
        widget.ageGroup,
        widget.assessment,
        product: widget.product,
      );
      if (mounted) {
        setState(() => _text = text);
      }
    } on GroqExplanationException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'AI explanation unavailable. The age-based result and reasons above still apply.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

/// Visible label evidence makes matching colours distinguishable from a
/// reused result. It also shows when a product's data is actually missing.
class _FamilyLabelFacts extends StatelessWidget {
  const _FamilyLabelFacts({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    double? value(Nutrient nutrient) {
      final double? number = product.nutriments?.getValue(
        nutrient,
        PerSize.oneHundredGrams,
      );
      return number != null && number.isFinite && number >= 0 ? number : null;
    }

    final double? sodium = value(Nutrient.sodium);
    final double? salt =
        value(Nutrient.salt) ?? (sodium == null ? null : sodium * 2.5);
    String grams(double? number) =>
        number == null ? 'not provided' : '${number.toStringAsFixed(2)} g';
    final bool drink =
        product.categoriesTags?.contains('en:beverages') ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Label per ${drink ? '100 ml' : '100 g'} · as sold',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(
          'Sugars ${grams(value(Nutrient.sugars))} · Salt ${grams(salt)} · Saturated fat ${grams(value(Nutrient.saturatedFat))}',
        ),
        if (product.barcode?.isNotEmpty == true)
          Text(
            'Product: ${product.barcode}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          'Same colour can mean the same concern. Open each member for age-specific reasons.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
