%dw 2.0
import fail from dw::Runtime
// Common quote format for the three providers. The currency always comes from the provider response.

// Resilience reasons that mean "the provider is unavailable right now" (503); anything else is a provider error (502).
var unavailableReasons = ["TIMEOUT", "CIRCUIT_OPEN", "CONNECTIVITY", "CANNOT_DISPATCH", "RETRY_EXHAUSTED"]

fun nowUtc() = (now() >> "UTC") as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}

// A provider answered with the product -> { found: true, quote: Quote }
fun found(abv: String, externalId, name, price, currency) =
	if (currency == null) fail("Provider " ++ abv ++ " answered without a currency")
	else {
		found: true,
		quote: {
			abv: abv,
			externalId: externalId as Number,
			(name: name) if (name != null),
			price: price as Number,
			currency: currency,
			quotedAt: nowUtc()
		}
	}

// The provider does not know the product: a valid answer, not a failure (it does not open the circuit)
var notFound = { found: false }

// vars.rsResult of one provider -> one entry of the parallel quote
fun outcome(abv: String, externalId, rsResult) =
	if ((rsResult.ok default false) and (rsResult.payload.found default false))
		{ abv: abv, externalId: externalId as Number, quote: rsResult.payload.quote }
	else
		{
			abv: abv,
			externalId: externalId as Number,
			reason:
				if (rsResult.ok default false) "NOT_FOUND"
				else if (rsResult.reason == "TIMEOUT") "TIMEOUT"
				else if (rsResult.reason == "CIRCUIT_OPEN") "CIRCUIT_OPEN"
				else "ERROR"
		}
