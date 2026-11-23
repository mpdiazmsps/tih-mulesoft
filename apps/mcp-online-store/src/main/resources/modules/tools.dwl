%dw 2.0
// Adapts request_correction to papi-order-requests: the request body and its derived idempotency key.
// No business decision is taken here: the item, the missing quantity and the quotes come from papi-orders.

// Provider of a RESTOCK: the one the agent chose, or the cheapest one of the alternatives.
fun restockProvider(args, alternatives) = args.provider default alternatives.cheapest.provider

// D7/tools.yaml: the key is derived from the order, the type and the provider; asking twice returns the same request.
fun idempotencyKey(args, provider) = args.orderId ++ ":" ++ args."type" ++ ":" ++ (provider default "none")

// Body of POST /order-requests. RESTOCK takes the item, the missing quantity (unless the agent gave one) and the quoted
// price of the chosen provider from the alternatives.
fun requestBody(args, alternatives, provider) =
	if (args."type" == "RESTOCK")
		{
			orderId: args.orderId,
			"type": "RESTOCK",
			detail: {
				itemId: alternatives.itemId,
				quantity: args.quantity default alternatives.shortage,
				provider: provider,
				price: ((alternatives.quotes default []) filter ($.provider == provider))[0].price,
				currency: alternatives.currency default "MXN"
			}
		}
	else
		{ orderId: args.orderId, "type": args."type" }

// A RESTOCK needs an order with a stock shortage and a quote of the provider.
fun restockProblem(alternatives, provider) =
	if (alternatives."type" != "RESTOCK") "The order has no stock shortage: it needs " ++ (alternatives."type" default "no correction")
	else if (isEmpty((alternatives.quotes default []) filter ($.provider == provider))) "There is no quote of provider " ++ (provider default "none") ++ " for this order"
	else null
