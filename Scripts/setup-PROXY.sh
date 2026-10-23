# DELETE Pre-Configured logs-proxysg.log templates
curl -X DELETE "https://es.elastic.lab/_index_template/logs-proxysg.log" -H "Content-Type: application/json" -u "sdg:changeme"
curl -X DELETE "https://es.elastic.lab/_component_template/logs-proxysg.log@package" -H "Content-Type: application/json" -u "sdg:changeme"

# Recreate them in your image
curl -X PUT "https://es.elastic.lab/_component_template/logs-proxysg.log@package" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Component-Templates/logs-proxysg.log.json
curl -X PUT "https://es.elastic.lab/_index_template/logs-proxysg.log" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/logs-proxysg.log.json

# Begin data generation
# Begin data generation
python3 -m venv venv && source venv/bin/activate
pip install -r /home/elastic/SDGpy/requirements.txt
python3 /home/elastic/SDGpy/sdg.py /home/elastic/SDGpy/Tracks/saife-proxy.yml
