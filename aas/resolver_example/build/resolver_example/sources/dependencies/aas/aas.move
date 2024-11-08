module aas::aas {
    use std::error;
    use std::signer;
    use std::string::{Self, String};

    use aas::schema;
    use aas::attestation;
    use aas::resolver_dispatcher;
    
    /*********** Error Codes ***********/
    
    const ESTRING_TOO_LONG: u64 = 1;
    const ENOT_SCHEMA_CREATOR: u64 = 2;
    const E_NOT_REVOKABLE: u64 = 3;
    const EATTESTATION_NOT_FOUND: u64 = 4;
    const EATTESTATION_ALREADY_REVOKED: u64 = 5;
    const EATTESTATIONS_NOT_EXIST_AT_ADDRESS: u64 = 6;
    const ESCHEMA_NOT_FOUND: u64 = 7;
    const ERESOLVE_FAILED: u64 = 8;

    /*********** Entry Functions ***********/

    /// Create a new schema
    public entry fun create_schema(
        creator: &signer, 
        schema: vector<u8>, 
        name: String, 
        description: String, 
        url: String, 
        revokable: bool,
        resolver: address,
    ) {
        create_schema_and_get_schema_address(creator, schema, name, description, url, revokable, resolver);
    }

    /// Create a new attestation
    public entry fun create_attestation(
        attestor: &signer, 
        recipient: address,
        schema_addr: address, 
        ref_attestation: address, 
        expiration_time: u64, 
        revokable: bool, 
        data: vector<u8>
    ) {
        create_attestation_and_get_address(attestor, recipient, schema_addr, ref_attestation, expiration_time, revokable, data);
    }

    /// Revoke an attestation
    public entry fun revoke_attestation(
        admin: &signer,
        schema_addr: address,
        attestation: address,
    ) {
        let admin_addr = signer::address_of(admin);
        assert!(schema::schema_exists(schema_addr), error::invalid_argument(ESCHEMA_NOT_FOUND));
        assert!(attestation::attestation_exists(attestation), error::invalid_argument(EATTESTATION_NOT_FOUND));
        let resolver = schema::schema_resolver(schema_addr);
        if (resolver != @0x0) {
            assert!(
                resolver_dispatcher::on_revoke(resolver, admin_addr, schema_addr, attestation),
                error::unauthenticated(ERESOLVE_FAILED)
            );
        };
        
        assert!(admin_addr == schema::schema_creator(schema_addr), error::invalid_argument(ENOT_SCHEMA_CREATOR));
        assert!(schema::schema_revokable(schema_addr), error::invalid_argument(E_NOT_REVOKABLE));

        attestation::revoke_attestation(attestation);
    }

    /*********** Public Functions ***********/

    public fun create_schema_and_get_schema_address(
        creator: &signer, 
        schema: vector<u8>, 
        name: String, 
        description: String, 
        url: String, 
        revokable: bool,
        resolver: address,
    ): address {
        assert!(string::length(&name) < 128, error::invalid_argument(ESTRING_TOO_LONG));
        assert!(string::length(&description) < 512, error::invalid_argument(ESTRING_TOO_LONG));
        assert!(string::length(&url) < 512, error::invalid_argument(ESTRING_TOO_LONG));

        schema::create_schema(signer::address_of(creator), name, description, url, revokable, resolver, schema)
    }

    public fun create_attestation_and_get_address(
        attestor: &signer, 
        recipient: address,
        schema_addr: address, 
        ref_attestation: address, 
        expiration_time: u64, 
        revokable: bool, 
        data: vector<u8>
    ): address {
        assert!(!attestation::attestation_exists(ref_attestation), error::invalid_argument(EATTESTATIONS_NOT_EXIST_AT_ADDRESS));
        assert!(schema::schema_exists(schema_addr), error::invalid_argument(ESCHEMA_NOT_FOUND));
        let resolver = schema::schema_resolver(schema_addr);
        if (resolver != @0x0) {
            assert!(
                resolver_dispatcher::on_attest(resolver, signer::address_of(attestor), recipient, schema_addr, ref_attestation, expiration_time, revokable, data),
                error::unauthenticated(ERESOLVE_FAILED)
            );
        };
        
        attestation::create_attestation(signer::address_of(attestor), recipient, schema_addr, ref_attestation, expiration_time, revokable, data)
    }

}