# Known Limitations

- Power Platform cmdlet output can vary by module version and tenant configuration.
- Ownership metadata is not perfectly consistent across apps and flows, so orphan detection is best-effort and includes a confidence field.
- Connector extraction depends on what the underlying cmdlets expose. Some connector relationships may be incomplete.
- Flow and app sharing breadth is not fully expanded in this first pass.
- Unmanaged solution usage is called out as a governance concern in project goals, but dedicated solution inventory is not included in this version.
- Some tenants may require additional permissions for DLP policy export.
