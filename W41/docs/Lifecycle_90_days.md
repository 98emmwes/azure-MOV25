  {
    "type": "Microsoft.Storage/storageAccounts/managementPolicies",
    "apiVersion": "2023-01-01",
    "name": "[format('{0}/default', variables('storageAccountName'))]",
    "dependsOn": [ "[resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName'))]" ],
    "properties": {
      "policy": {
        "rules": [
          {
            "name": "dokument-till-cool",
            "enabled": true,
            "type": "Lifecycle",
            "definition": {
              "filters": { "blobTypes": [ "blockBlob" ], "prefixMatch": [ "dokument/" ] },
              "actions": { "baseBlob": { "tierToCool": { "daysAfterModificationGreaterThan": 90 } } }
            }
          }
        ]
      }
    }
  }
