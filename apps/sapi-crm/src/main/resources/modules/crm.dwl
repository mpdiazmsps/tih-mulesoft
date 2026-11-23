%dw 2.0
// Salesforce Contact <-> common Customer. The segment comes from the custom field Segmento__c (values in Spanish).

var contactFields = "Id, Name, Email, Phone, Segmento__c, MailingStreet, MailingCity, MailingState, MailingPostalCode"

var segmentFromSalesforce = { "Estratégico": "STRATEGIC", "Regular": "REGULAR" }
var segmentToSalesforce = { STRATEGIC: "Estratégico", REGULAR: "Regular" }

// Resilience reasons that mean "Salesforce is unavailable right now" (503); anything else is a Salesforce error (502)
var unavailableReasons = ["TIMEOUT", "CONNECTIVITY", "UNAVAILABLE", "LIMIT_EXCEEDED", "COMMUNICATION", "CIRCUIT_OPEN", "RETRY_EXHAUSTED", "UNKNOWN"]

fun opt(key: String, v) = if (v == null or v == "") {} else { (key): v }

// Contact record -> Customer
fun toCustomer(c) =
	{ id: c.Id, name: c.Name }
	++ opt("email", c.Email)
	++ opt("phone", c.Phone)
	++ { segment: segmentFromSalesforce[c.Segmento__c default ""] default "REGULAR" }
	++ (if (c.MailingCity == null) {} else {
		address: { city: c.MailingCity }
			++ opt("street", c.MailingStreet)
			++ opt("state", c.MailingState)
			++ opt("postalCode", c.MailingPostalCode)
	})

// The org has state and country picklists: a state needs its country, and the valid value is "Mexico"
var mailingCountry = "Mexico"

// CustomerRequest -> Contact fields (the full name goes to LastName; REGULAR when no segment is sent)
fun toContact(r) =
	{ LastName: r.name, Segmento__c: segmentToSalesforce[r.segment default "REGULAR"] }
	++ (if (r.address == null) {} else { MailingCountry: mailingCountry })
	++ opt("Email", r.email)
	// Unique lowercase copy of the email: Salesforce rejects a second insert with DUPLICATE_VALUE even when both
	// arrive at the same time (the duplicate rule does not see simultaneous inserts). D22.
	++ opt("Email_Key__c", if (r.email == null) null else lower(r.email))
	++ opt("Phone", r.phone)
	++ opt("MailingStreet", r.address.street)
	++ opt("MailingCity", r.address.city)
	++ opt("MailingState", r.address.state)
	++ opt("MailingPostalCode", r.address.postalCode)

// The Customer just created: the request plus the Salesforce Id and the default segment
fun createdCustomer(id: String, r) =
	{ id: id, name: r.name }
	++ opt("email", r.email)
	++ opt("phone", r.phone)
	++ { segment: r.segment default "REGULAR" }
	++ (if (r.address == null) {} else { address: r.address })

// "id1,id2" -> 'id1','id2'. The contract only lets 18 alphanumeric characters through, so no escaping is needed.
fun soqlIdList(ids: String) = ((ids splitBy ",") map ("'" ++ trim($) ++ "'")) joinBy ","
