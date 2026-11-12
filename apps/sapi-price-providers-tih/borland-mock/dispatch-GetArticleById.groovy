// Dispatch SCRIPT de la operación GetArticleById: devuelve el NOMBRE de la respuesta a usar.
// Las respuestas se llaman "1" ... "5" y "desconocido".
def holder = new com.eviware.soapui.support.XmlHolder(mockRequest.requestContent)
holder.namespaces['tem'] = 'http://tempuri.org/'
def id = holder.getNodeValue('//tem:ArticleId')
return (id in ['1', '2', '3', '4', '5']) ? id : 'desconocido'
