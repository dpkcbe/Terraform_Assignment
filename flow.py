from prefect import flow

@flow(name="hello-flow")
def hello():
    print("Hello from Prefect!")

if __name__ == "__main__":
    hello()
