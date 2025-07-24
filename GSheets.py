import os
import time
import gspread
from google.oauth2 import service_account

from datetime import datetime
x = 5
def append_to_google_sheets(data, row):
    # Use credentials to create a client to interact with the Google Drive API
    json_credentials = 'keys.json'
    creds = service_account.Credentials.from_service_account_file(json_credentials, scopes=[
        "https://spreadsheets.google.com/feeds",
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/drive"
    ])
    client = gspread.authorize(creds)
    spreadsheet = client.open_by_key('1tqfeChz5OG2ViIr5MpFy-OEds_SDohqzbQOGO0Dv-EI')
    sheet = spreadsheet.get_worksheet(0)

    # If the sheet is not empty, shift the rest down
    new_body = [row.split(",") for row in data.split("\n") if row]

    # # Define your header
    # header = ["date","time","active_trade","direction","balance","amount","Streak (P|D|L|win_rate)","debug"]  # Adjust as needed
    # # Get all values in the sheet
    # all_values = sheet.get_all_values()
    #
    # # Limit the number of rows to avoid lag
    # max_rows = 10000  # Adjust as needed
    # if all_values:
    #     body = all_values[1:]
    #     updated_values = [header] + new_body + body
    #     if len(updated_values) > max_rows:
    #         updated_values = updated_values[:max_rows]
    # else:
    #     # If the sheet is empty, just add the header and new data
    #     updated_values = [header] + new_body
    #     if len(updated_values) > max_rows:
    #         updated_values = updated_values[:max_rows]
    #
    # Clear the sheet and update with new values
    # sheet.clear()
    # sheet.update(updated_values)
    
    # Insert multiple rows at once
    if row == 1:
        sheet.update(new_body, 'A1')
    else:
        sheet.insert_rows(new_body, row=row)
        # Ensure the number of rows does not exceed 20000
        all_values = sheet.get_all_values()
        if len(all_values) > 20000:
            sheet.delete_rows(20001, len(all_values))

def monitor_log(file_path):

    header = ["date","time","active_trade","amount","E","F","balance",'next_target',"last_trade","payout (coin)","Streak (W|D|L|win_rate)","Streaks","ohlc","debug"]  # Adjust as needed
    last_size = 0

    # Ensure the header is set before starting the loop
    try:
        append_to_google_sheets(",".join(header), 1)
    except Exception as e:
        print(f'Error setting header:\n{e}')
        return

    last_file_size = os.path.getsize(file_path)
    
    while True:
        try:
            with open(file_path, "r") as f:
                f.seek(last_size)  # Move to last read position
                new_data = f.read()
                last_size = f.tell()  # Get current file size
            
            if os.path.getsize(file_path) < last_file_size:
                last_file_size = os.path.getsize(file_path)
                last_size = 0
                print(f"{datetime.now()} | File has been cleared, resetting last_size")
                continue

            if new_data:
                last_file_size = os.path.getsize(file_path)
                data_to_output = new_data.strip()
                # Reverse the order of the new data
                reversed_data = "\n".join(data_to_output.split("\n")[::-1])

                # Append reversed data to Google Sheets
                try:
                    append_to_google_sheets(reversed_data, 2)
                except Exception as e:
                    print(f'Error:\n{e}')
                    continue

                print(f'{datetime.now()} | Worksheet updated successfully')
                time.sleep(15)  # Adjust as needed
            else:
                print(f'{datetime.now()} | No new data')
                time.sleep(5)  # Adjust as needed

        except FileNotFoundError:
            print(f"{datetime.now()} | Waiting for log file...")
            last_size = 0
            time.sleep(5)  # Adjust as needed
            continue
        except PermissionError:
            print(f"{datetime.now()} | Permission Error...")
            time.sleep(5)  # Adjust as needed
            continue

if __name__ == "__main__":
    monitor_log("log.csv")
