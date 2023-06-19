#This generates an env-vars file that the project uses for various tasks, mostly testing. If you want to modify the env vars, open .env-vars in the root dir.
#It also generates a .swift file in the project that contains the env vars as swift constants for easy use. Check EnvVars.generated.swift

if [ ! -f ".env-vars" ]; then
    touch .env-vars
    echo "export TEST_SERVER_URL=" >> .env-vars
    echo "export TEST_USER=" >> .env-vars
    echo "export TEST_APP_PASSWORD=" >> .env-vars
    #add more env vars here
fi

source .env-vars

Sourcery/bin/sourcery --templates Sourcery --output Sources/NextcloudKit/Generated --sources . --args TEST_USER=$TEST_USER,TEST_APP_PASSWORD=$TEST_APP_PASSWORD,TEST_SERVER_URL=$TEST_SERVER_URL

