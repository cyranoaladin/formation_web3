export type Security02UnverifiedPda = {
  "version": "0.1.0",
  "name": "security_02_unverified_pda",
  "instructions": [
    {
      "name": "initialize",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "vault",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "createFakeUserStats",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "setPoints",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "user",
          "isMut": false,
          "isSigner": true
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "claimReward",
      "accounts": [
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "vault",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": []
    }
  ],
  "accounts": [
    {
      "name": "userStats",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "points",
            "type": "u64"
          },
          {
            "name": "bump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "vault",
      "type": {
        "kind": "struct",
        "fields": []
      }
    }
  ],
  "errors": [
    {
      "code": 6000,
      "name": "NotEnoughPoints",
      "msg": "Not enough points"
    },
    {
      "code": 6001,
      "name": "VaultEmpty",
      "msg": "Vault empty"
    }
  ]
};

export const IDL: Security02UnverifiedPda = {
  "version": "0.1.0",
  "name": "security_02_unverified_pda",
  "instructions": [
    {
      "name": "initialize",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "vault",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "createFakeUserStats",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "setPoints",
      "accounts": [
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "user",
          "isMut": false,
          "isSigner": true
        }
      ],
      "args": [
        {
          "name": "points",
          "type": "u64"
        }
      ]
    },
    {
      "name": "claimReward",
      "accounts": [
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "userStats",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "vault",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": []
    }
  ],
  "accounts": [
    {
      "name": "userStats",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "points",
            "type": "u64"
          },
          {
            "name": "bump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "vault",
      "type": {
        "kind": "struct",
        "fields": []
      }
    }
  ],
  "errors": [
    {
      "code": 6000,
      "name": "NotEnoughPoints",
      "msg": "Not enough points"
    },
    {
      "code": 6001,
      "name": "VaultEmpty",
      "msg": "Vault empty"
    }
  ]
};
