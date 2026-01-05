sudo docker run -d --name cohorter-webapp --network cohorter-net -p 3003:3000 -e NL2DSL_SERVER="http://cohorter-nl2dsl:3002/api/compile" cohorter-webapp
