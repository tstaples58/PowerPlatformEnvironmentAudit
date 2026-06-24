# Permissions

The toolkit is intended for read-only administrative auditing.

## Power Platform

Recommended access:

- Power Platform Administrator, Global Administrator, or equivalent delegated admin access that can read environment, app, flow, and DLP data
- Ability to run the `Microsoft.PowerApps.Administration.PowerShell` and `Microsoft.PowerApps.PowerShell` cmdlets

## Microsoft Graph

Graph is optional and used only for user enrichment where Power Platform data returns object identifiers without friendly names.

Recommended delegated scopes:

- `Directory.Read.All`
- `User.Read.All`

## Notes

- Some cmdlets return different properties depending on tenant configuration and module version.
- DLP policy visibility may require higher privilege than app or flow inventory collection.
- If Graph scopes are not granted, the toolkit still runs and records unresolved owners where possible.
