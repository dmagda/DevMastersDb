# Getting Started With PostgresML

The video introduces you to the [PostgresML extension](https://postgresml.org) that turns Postgres into a complete MLOps platform.

[![@DevMastersDB](https://github.com/dmagda/DevMastersDb/assets/1537233/de462b5f-b8f4-41e9-a2da-748076cdafe2)](https://www.youtube.com/watch?v=Gtz883daf1Y)

Follow the guide to learn how to:

* Start a PostgresML instance on your own machine
* Use the extension for translation from English to French and Spanish
* Perform sentiment analysis with PostgresML 

## Start PostgresML

1. Start and connect to an instance of Postgres with PostgresML:
    ```shell
    docker run \
        -it \
        -v postgresml_data:/var/lib/postgresql \
        -p 5433:5432 \
        -p 8000:8000 \
        ghcr.io/postgresml/postgresml:2.7.12 \
        sudo -u postgresml psql -d postgresml
    ```
2. Make sure you can see the `pgml` extension in the list:
    ```sql
    select * from pg_extension;
    ```
3. Take a look at tables and other database objects used by the extension:
    ```sql  
    \d
    ```

## Text Translation with PostgresML

1. Use the default translation transformation to translate a text from English to French:
    ```sql
    SELECT pgml.transform(
        'translation_en_to_fr',
        inputs => ARRAY[
            'How can I get to the nearest subway station?'
        ]
    ) AS french;
    ```
2. Use one of the [Helsinki NLP's model](https://huggingface.co/Helsinki-NLP/opus-mt-en-es) to translate the same text but to Spanish:
    ```sql
    select pgml.transform(
        task => '{"task": "translation", 
                "model": "Helsinki-NLP/opus-mt-en-es"
        }'::JSONB,
        inputs => ARRAY[
            'How can I get to the nearest subway station?'
        ]   
    ) as spanish;
    ```

## Sentiment Analysis With PostgresML

1. Evaluate the sentiment of the following two comments with a default classification model:
    ```sql
    SELECT pgml.transform(
        task   => 'text-classification',
        inputs => ARRAY[
            'I love how amazingly simple ML has become!',
            'I hate doing mundane and thankless tasks. ☹️'
        ]
    ) AS positivity;
    ```
2. Change *hate* to *love* in the second comment to see how the rank changes from negative to positive:
    ```sql
    SELECT pgml.transform(
        task   => 'text-classification',
        inputs => ARRAY[
            'I love how amazingly simple ML has become!',
            'I love doing mundane and thankless tasks.'
        ]
    ) AS positivity;
    ```
3. Use the [RoBERTa model](https://huggingface.co/finiteautomata/bertweet-base-sentiment-analysis) trained on around 40,000 English tweets to asses the sentiment for comments from one of [my social media posts](https://www.linkedin.com/feed/update/urn:li:activity:7141899952661614592/):
    ```sql
    select pgml.transform(
        task => '{"task": "text-classification",
                "model": "finiteautomata/bertweet-base-sentiment-analysis"
                }'::jsonb,
        inputs => array[
            'Nice! finally something to motivate me to get my ass off the couch and go learn something AI cant do, until it can.',
            'Does anecdotical evidence qualify for an evidence?',
            'Are you not using your brain or is this an AI comment? :)) How is the junior supposed to evolve into a senior if he is not going to do junior and mid level development? Smells like a load of bs anyway...'
            ]
    ) as positivity;
    ```

Hope you found this tutorial useful! Reach out to me on Twitter (X) for any feedback, questions or suggestions you might have:
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/denismagda.svg?style=social&label=Follow%20%40DenisMagda)](https://twitter.com/DenisMagda)

 
