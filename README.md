# Foobar

A short program to execute github repo health score

## Description

The score will based on 5 criteria: \
Average number of commits (push) per day \
Average response time of first response to an issue \
Average time that an issue remains opened \
Average time for a pull request to get merged \
Average number of comments per pull requests \
Ratio of closed to open issues 

Each rule will give a score from 0-1. A mean score will represent health
## Installation 
Maven is required. 3.6.1 \
Google Cloud \
Get Google Cloud services account key at below 
```bash
GOOGLE_APPLICATION_CREDENTIALS = [PATH TO JSON FILE]
```

## Usage
```
You can query in Bigquery with github_scoring.SQL file
```
--OR--
Compile
```bash
mvn clean package
```
Run Class to print out top 1000 repos
```bash
mvn exec:java -Dexec.mainClass="com.quod.ai.App" -Dexec.args="BQ.txt"
```

## Contributing
Chuong NM: beenchuong@gmail.com

## License
[MIT](https://choosealicense.com/licenses/mit/)
