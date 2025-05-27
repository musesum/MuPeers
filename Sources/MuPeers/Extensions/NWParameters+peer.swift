
import Network
import CryptoKit

extension NWParameters {

    static func make(secret: String) -> NWParameters {
        if secret.count > 0 {
            // no secret, so skip TLS
            return NWParameters(secret: secret)
        } else {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let options = NWProtocolFramer.Options(definition: PeerFramer.definition)
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
            return parameters
        }
    }

	// Create parameters for use in PeerConnection and PeerListener.
	convenience init(secret: String) {

		// Customize TCP options to enable keepalives.
		let tcpOptions = NWProtocolTCP.Options()
		tcpOptions.enableKeepalive = true
		tcpOptions.keepaliveIdle = 2

		// Create parameters with custom TLS and TCP options.
		self.init(tls: NWParameters.tlsOptions(secret), tcp: tcpOptions)

		// Enable using a peer-to-peer link.
		self.includePeerToPeer = true

		// Add your custom protocol
		let options = NWProtocolFramer.Options(definition: PeerFramer.definition)
		self.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
	}

	// Create TLS options using a passcode to derive a preshared key.
	private static func tlsOptions(_ secret: String) -> NWProtocolTLS.Options {
		let tlsOptions = NWProtocolTLS.Options()

		let authenticationKey = SymmetricKey(data: secret.data(using: .utf8)!)
		let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: "MuPeers".data(using: .utf8)!, using: authenticationKey)

		let authenticationDispatchData = authenticationCode.withUnsafeBytes {
			DispatchData(bytes: $0)
		}

        sec_protocol_options_add_pre_shared_key(
            tlsOptions.securityProtocolOptions,
            authenticationDispatchData as __DispatchData,
            stringToDispatchData("MuPeers")! as __DispatchData)

        // the following is only in TLS 1.2, removing should allow both TLS 1.3, when available, and fallback to TLS 1.2 
        // sec_protocol_options_append_tls_ciphersuite(tlsOptions.securityProtocolOptions, tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)

		return tlsOptions
	}

	// Create a utility function to encode strings as preshared key data.
	private static func stringToDispatchData(_ string: String) -> DispatchData? {
		guard let stringData = string.data(using: .utf8) else {
			return nil
		}
		let dispatchData = stringData.withUnsafeBytes {
			DispatchData(bytes: $0)
		}
		return dispatchData
	}
}
