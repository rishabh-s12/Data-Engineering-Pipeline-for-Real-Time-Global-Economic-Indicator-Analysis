import boto3
import csv
import io

s3 = boto3.client('s3')

# ✅ Updated processed bucket name
PROCESSED_BUCKET = 'dea-project-rishabh-processed1'

# --- Country normalization mapping ---
COUNTRY_MAP = {
    "USA": "United States",
    "U.S.": "United States",
    "UK": "United Kingdom",
    "U.K.": "United Kingdom"
}

def normalize_country(name):
    name = name.strip()
    return COUNTRY_MAP.get(name, name)


def is_valid_row(row):
    try:
        if any(field.strip() == "" for field in row):
            return False

        gdp = float(row[3])
        population = float(row[4])
        gdp_pc = float(row[5])

        if gdp <= 0 or population <= 0 or gdp_pc <= 0:
            return False

        return True

    except:
        return False


def remove_outliers(rows):
    cleaned = []

    for row in rows:
        gdp = float(row[3])
        population = float(row[4])
        gdp_pc = float(row[5])

        if gdp > 1e15:
            continue
        if population > 2e9:
            continue
        if gdp_pc > 200000:
            continue

        cleaned.append(row)

    return cleaned


def validate_logic(rows):
    valid_rows = []

    for row in rows:
        gdp = float(row[3])
        population = float(row[4])
        gdp_pc = float(row[5])

        calculated = gdp / population

        if abs(calculated - gdp_pc) / gdp_pc < 0.05:
            valid_rows.append(row)

    return valid_rows


def remove_duplicates(rows):
    seen = set()
    unique_rows = []

    for row in rows:
        key = (row[0], row[2])  # country_code + year

        if key not in seen:
            seen.add(key)
            unique_rows.append(row)

    return unique_rows


def lambda_handler(event, context):

    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']

    print(f"Processing file: {file_key}")

    response = s3.get_object(Bucket=bucket_name, Key=file_key)
    csv_content = response['Body'].read().decode('utf-8')

    reader = csv.reader(io.StringIO(csv_content))
    header = next(reader)

    total_rows = 0
    valid_rows = []

    for row in reader:
        total_rows += 1

        if is_valid_row(row):
            row[1] = normalize_country(row[1])
            valid_rows.append(row)

    print(f"After missing/invalid removal: {len(valid_rows)}")

    unique_rows = remove_duplicates(valid_rows)
    print(f"After duplicate removal: {len(unique_rows)}")

    no_outliers = remove_outliers(unique_rows)
    print(f"After outlier removal: {len(no_outliers)}")

    final_rows = validate_logic(no_outliers)
    print(f"After logical validation: {len(final_rows)}")

    output_csv = io.StringIO()
    writer = csv.writer(output_csv)

    writer.writerow(header)
    writer.writerows(final_rows)

    processed_file_key = file_key.replace('raw/', 'processed/')

    s3.put_object(
        Bucket=PROCESSED_BUCKET,
        Key=processed_file_key,
        Body=output_csv.getvalue()
    )

    return {
        'statusCode': 200,
        'body': f"Final cleaned rows: {len(final_rows)} from {total_rows}"
    }
