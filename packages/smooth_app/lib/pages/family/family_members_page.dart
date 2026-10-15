import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/family_member.dart';
import 'package:smooth_app/data_models/family_profiles.dart';

Future<void> openFamilyMembers(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FamilyMembersPage()),
    );

class FamilySetupPrompt extends StatelessWidget {
  const FamilySetupPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final FamilyProfiles? profiles = context.watch<FamilyProfiles?>();
    if (profiles == null) {
      return const SizedBox.shrink();
    }
    final int count = profiles.members.length;
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.family_restroom),
        title: const Text('My family'),
        subtitle: Text(
          count == 0
              ? 'Add names and ages for personal product checks'
              : '$count family ${count == 1 ? 'member' : 'members'} · age-based product checks',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openFamilyMembers(context),
      ),
    );
  }
}

class FamilyMembersPage extends StatelessWidget {
  const FamilyMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FamilyProfiles profiles = context.watch<FamilyProfiles>();
    return Scaffold(
      appBar: AppBar(title: const Text('My family')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Food choices for everyone',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add yourself and your family members. Search or scan a food product to see a separate age-based result for each person.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Names and ages are saved only on this device. Age is in completed years; use 0 for babies under 1.',
            ),
            const SizedBox(height: 20),
            if (profiles.members.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No family members yet. Add your first member below.',
                  ),
                ),
              ),
            for (final FamilyMember member in profiles.members)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(member.name),
                  subtitle: Text(
                    '${member.age} ${member.age == 1 ? 'year' : 'years'} · ${member.ageGroup.label}',
                  ),
                  trailing: Wrap(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Edit ${member.name}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: profiles.saving
                            ? null
                            : () => _edit(context, member),
                      ),
                      IconButton(
                        tooltip: 'Remove ${member.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: profiles.saving
                            ? null
                            : () => _remove(context, profiles, member),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: profiles.saving ? null : () => _edit(context, null),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add family member'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, FamilyMember? member) =>
      showDialog<void>(
        context: context,
        builder: (_) => _FamilyMemberDialog(
          profiles: context.read<FamilyProfiles>(),
          member: member,
        ),
      );

  Future<void> _remove(
    BuildContext context,
    FamilyProfiles profiles,
    FamilyMember member,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'Their saved details will be removed from this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await profiles.remove(member.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this member. Please try again.'),
          ),
        );
      }
    }
  }
}

class _FamilyMemberDialog extends StatefulWidget {
  const _FamilyMemberDialog({required this.profiles, this.member});
  final FamilyProfiles profiles;
  final FamilyMember? member;

  @override
  State<_FamilyMemberDialog> createState() => _FamilyMemberDialogState();
}

class _FamilyMemberDialogState extends State<_FamilyMemberDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.member?.name,
  );
  late final TextEditingController _age = TextEditingController(
    text: widget.member?.age.toString(),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.member == null ? 'Add family member' : 'Edit family member',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (String? value) =>
                    value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _age,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(
                  labelText: 'Age in years',
                  helperText: '0 for babies under 1 · maximum 120',
                ),
                validator: (String? value) {
                  final int? age = int.tryParse(value ?? '');
                  return age == null || age < 0 || age > 120
                      ? 'Enter an age from 0 to 120'
                      : null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.profiles.save(
        id: widget.member?.id,
        name: _name.text,
        age: int.parse(_age.text),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }
}
