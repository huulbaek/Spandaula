// Fake profile data for demo mode
// This provides realistic-looking Danish names instead of real user data

/// Game players for demo mode (matches IDs in demo_games.dart)
const demoGamePlayers = [
  {'id': 1000001, 'name': 'Anders Hansen'},
  {'id': 1000101, 'name': 'Sofie Nielsen'},
  {'id': 1000102, 'name': 'Magnus Pedersen'},
  {'id': 1000103, 'name': 'Freja Christensen'},
  {'id': 1000104, 'name': 'Oscar Larsen'},
  {'id': 1000105, 'name': 'Ida Andersen'},
  {'id': 1000106, 'name': 'Victor Mortensen'},
  {'id': 1000107, 'name': 'Clara Jørgensen'},
];

const demoProfileData = {
  'profiles': [
    {
      'id': 1000001,
      'profileId': 1000001,
      'firstName': 'Anders',
      'lastName': 'Hansen',
      'email': 'demo@example.dk',
      'profilePicture': null,
      'institutionProfiles': [
        {
          'id': 1000002,
          'institutionCode': '123456',
          'institutionName': 'Skovbrynet Skole',
        },
        {
          'id': 1000003,
          'institutionCode': '234567',
          'institutionName': 'Bakketoppen Børnehave',
        },
      ],
      'children': [
        {
          'id': 1000010,
          'name': 'Emma Hansen',
          'firstName': 'Emma',
          'lastName': 'Hansen',
          'profilePicture': null,
          'institutionProfile': {
            'id': 1000011,
            'institutionName': 'Skovbrynet Skole',
          },
        },
        {
          'id': 1000020,
          'name': 'Oliver Hansen',
          'firstName': 'Oliver',
          'lastName': 'Hansen',
          'profilePicture': null,
          'institutionProfile': {
            'id': 1000021,
            'institutionName': 'Bakketoppen Børnehave',
          },
        },
      ],
    },
  ],
};
