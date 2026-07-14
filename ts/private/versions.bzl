"""Mirror npm registry metadata for the typescript package

Automatically mirrored using mirror_versions.sh and automated on GitHub Actions
"""

# Replaced during publishing, see .gitattributes
# Note: this requires a newer git version, 2.25.1 is too old, but GHA runs with 2.41.0 as of Sep 2023
RULES_TS_VERSION = "$Format:%(describe:tags=true)$"

NATIVE_TYPESCRIPT_VERSIONS = {
    "7.0.1-rc": {
        "integrity": "sha512-drEP77wK7CCDlPfXZH4e008UUQOsw1DFmHmZOZjuNA+yoDLLnSNMZRXi90NbV/1LVo7SbNLq1bs3jjvk49TEqQ==",
        "native_package_integrities": {
            "typescript-aix-ppc64": "sha512-oqq2ZfEJ7BQuufcC3QBQndZLPNyamYNHLao8lKRBeeSkZKypBqxPSgkzrcFZtbYcIaBvpiyUnQP9MT7DEYHWbw==",
            "typescript-darwin-arm64": "sha512-Slc0yTftT2F/uGDmtPst8ijydneL6uZaLEyr2UjahxZpbhTjHFBJ5agXtVz/TL4A+ldxzjzj+E8QtLZlh/5mXw==",
            "typescript-darwin-x64": "sha512-h68iFW/LbA1/BsGgSRGFw981/3s1f/rY27YrmeZNuN+ly7dI+fiDduwT9ZT9866x2onoKNRq7PTyxSKyKDzfAQ==",
            "typescript-freebsd-arm64": "sha512-DE+ppd8Ix2c6OMuRkKY4PJ4hngMGJ9M95OQUP17p9xL/1IKXof7npIeuusMN/bgL5o5JzMfSGh+N+5scTYRg0Q==",
            "typescript-freebsd-x64": "sha512-ST1ozHMw0u+CLOnWkcTyWDMV4Qn9osZ6fd1V1lnKDM1t0hZIp81mdGpdHxyHJjd7jdGrb6Gb/QXcZ1uqZ0t5zw==",
            "typescript-linux-arm": "sha512-gHmHwT5Naq5CKM8g9bbaGeEpnwQEvWCLn3fwP4K2m61VQdDKkPk0Dhab/OoZ4LV2SrMddmclYXTzpyg23YGt5g==",
            "typescript-linux-arm64": "sha512-N46pRihK3t5zD5MUtTQcdmQUqr1WI4U2nxno1gLwOtRSsB4krFkRjPHcQNG7h2DtRkX64rQiReX6WKwg2wprMA==",
            "typescript-linux-loong64": "sha512-G17Sao312rgiPBTh2F4nOpLpa3CcnBSaNhqNghZk2LNhnsp1RaMO5HMq2me21gqu9xLpc6CIgHtOzU6JBgNlfg==",
            "typescript-linux-mips64el": "sha512-0FQspOb5UsQ4tQKvWgUO3pS9OIWkP7/8dPRWq+CRazJUeQZ4LBjtYK52jg5iIOrvItrVl2CwvRtrU3/9OihwJg==",
            "typescript-linux-ppc64": "sha512-SUmwfVBEv6A2Ld0eWfcvW0FqrgemfQL8jFGOmV1qYxsDqumjE5DekHXqbstgmbE4SHr4rrjHjvmuGCY+kTH/vw==",
            "typescript-linux-riscv64": "sha512-rxeqnNnGiYzv/LlPHi/3+4p0ooR1cNJLjRIHXKovtiVmxXGJq6gtw8VSpbHuWPekyFMXgIAoLCZN0SQ51rAALQ==",
            "typescript-linux-s390x": "sha512-RYWCHCiPypxajdRHM2CNK/eM22e4Ex5TTjV2pXf7PTtBowGr0xX8i8kIMknyZS0LX2QfleYHouaoMVsFDSle3g==",
            "typescript-linux-x64": "sha512-PfLJSu0JzroDkqw2m4nqflPEcn8yev0m/vHFQlY9EzHorzjR6QG0wL8AJHvnD1e6h1s76AZngJ5u+z1K/D/HKw==",
            "typescript-netbsd-arm64": "sha512-FfbPxH3dTfp8yVIaNM7bdWTixXuyxpzoemluqcqMROSIz+ImpCG3Q9HO9Ptzp9/giv+P9YYEnCMSXh61migj2w==",
            "typescript-netbsd-x64": "sha512-FzdTfSzhRYb6hlav6K3cI5RVgcvCTvNAu/vc+t7B6AmZkThQ+t/1ntnvT5fnHmY1Az2RIBw7/b+qtCEG61HJTQ==",
            "typescript-openbsd-arm64": "sha512-PQGhlxfNig+0YQ9Wwzd0USPBkt6w/ZqkBQWsU7G/0JkTzunJel+jSWwhKw4947pak/m7hGSeYiI04xReDLGZww==",
            "typescript-openbsd-x64": "sha512-WJ7NYgO2mHmLUkI/tZ+hl8lFd26QPJqO8ONOHNuYbdsybLvSB6B6sep222JIVrOfPRDGvFinbGGB+l3m1FWRWA==",
            "typescript-sunos-x64": "sha512-UYjDeUxd765V9qcwlUPk4pEXyL0i3G76CJm9baK4i99u1pGO1psf3nXDw4MMmElVOPvGbZag99ZR/O59E2OX6w==",
            "typescript-win32-arm64": "sha512-KzXzFSXZOm7zvEt2Aw0MsB2LbTL88znAiVqTDNAOHdlEb7brgmUQh/X2wM/8Be+N0fjEqWKl65cBKNwpWEbJiw==",
            "typescript-win32-x64": "sha512-98R3+OqDr/r0/PLWEoXu88AE0lGVLNd335Ew8ONgzK1JWkNs4ou/5BGt3Or1ij4iXjH+c7PRL+jFjCbtWze+EA==",
        },
    },
    "7.0.2": {
        "integrity": "sha512-8FYau96o3NKOhbjKi/qNvG/W5jhzxkbdm5sj9AbZ/5T5sWqn3hJgLfGx27sRKZWTvyzCP8dLRBTf5tBTSRVUNA==",
        "native_package_integrities": {
            "typescript-aix-ppc64": "sha512-MTKKkWB7p/0E9xi1d1tHtZ5PiLkGEMIq88pK2CubZjOsLtYTLqhgIgi6zepFa+9GHZ6h05NMCkQxGKiPXMxXtQ==",
            "typescript-darwin-arm64": "sha512-gowzar9MwS/aRWp6f3a4KUqzRjAZjOsmGNCM6LcTgXum+dBfgsBVMN+AgvOCCbguXyick6LJhpBszxMebJ8syA==",
            "typescript-darwin-x64": "sha512-SZ9xZInqApNlNGc9s0W1VSsktYSOe9cFqNOIqmN1Gs8SmkjKZYFt017G4VwPxASInODuAdbTW7sXiFUf893RgA==",
            "typescript-freebsd-arm64": "sha512-W5NH4y/J0plIIS5b2xvTEkU7JFxyqdMAOgf+Ilhl0vHQXKO5dZoxd+C/jEtq56c4F3wk71RB4BMRQ2XdI+bwYQ==",
            "typescript-freebsd-x64": "sha512-UMGDx5sTpzNw3WiPebH7l90IWfJggEd+egHt/q6p7/Cm3zqoV7VxkGXt+3DxPIw8CcmvAB0j3sVVfbhX+M4Tpw==",
            "typescript-linux-arm": "sha512-gffT3xPz9sR7j/YJExkyPntrI0P2EP9XbOyWzth2/Gs0RstK+90RBcO0ncXoXy/beYll1SXw846Nf2zdnEz0QQ==",
            "typescript-linux-arm64": "sha512-Qh4eU4/y3yDjnfjjyPYihMj5/ODIlmt+Bzu17OI+fiSRDW57QmU5SiN63exPRNJPKUzcc1INa1NXdrJ+MqHjUQ==",
            "typescript-linux-loong64": "sha512-uEHck9i8hoAzXPiYRib1O7miOnz23SxIeVl6F4LXox+qov1K35jHcEW6VHKvZI+pyvl7fZEP4MCU5LYvIq1GuQ==",
            "typescript-linux-mips64el": "sha512-R4KvAMnE43W5Qeqb0Ly56O3mWMWIAgsMyz36DCaycd5nbg/9kzm0liw3JocfRqyJY0KPmzFjbswozXyW0DnIYA==",
            "typescript-linux-ppc64": "sha512-DORx5b3sd/4S7eayxm4FQv+A7CrkUIGRaHiwI8oiHTAI1fAPWhF4J0vAlkC8biAlHSVVwxMQ3tjZ2/DVbnQiiA==",
            "typescript-linux-riscv64": "sha512-wf0jqEDOjrPRnKwYRyyJDRo11KMbvMFrU+q4zqKyChODBzvlkbhNQfKvLxQCcwTpdDaXSHZTVuh0JoCrKCUMHQ==",
            "typescript-linux-s390x": "sha512-IkwJc3L7yhytWd/ewjyxNDfOmswCm9GWMJT/ue/dU4aZNbwZeYAetq42VyLmsmSjvoX7z74X6ZaYCtzAr0EuGw==",
            "typescript-linux-x64": "sha512-EYdf2cNg7rgCWJnxCdJ+F3V39O8ihb37eHAu1LK8oAFizgTQbPOK7zHHXbPt8rX24COqODXeI3sIf0fCXG7H/A==",
            "typescript-netbsd-arm64": "sha512-+polYF4MF04aPpO5FTkHran9yUQDSXqy5GiSDKpsll5jy3l3+g9QLhpf39T+ePtefhXLOGrLl0QIjkQP6VnelA==",
            "typescript-netbsd-x64": "sha512-8YIT0EHM/3dq10ZOVF/A7pc/YSMtbcecct4rWtexrnSCHOPcpC2KTLXfTCR6vDpnSiY12heNb1GiN/wu+T/FyA==",
            "typescript-openbsd-arm64": "sha512-APT8+ClYnuYm1u9+kgGXoMj2VzWzcymwh2gNSQVySHfkRDGOTVkoWLjCmOQSaO+PoqQ57B0flRp9SA+7GnnkzQ==",
            "typescript-openbsd-x64": "sha512-yX7s+Q0Dln0Dt9tEzZsAjXXR/+ytBM7AlglaqyeMPxQszJ1JhlJdZ6jLA+IzldHtflX81em7lDao1xXu+aRRkg==",
            "typescript-sunos-x64": "sha512-dLJDGaLZ1D4HPQn62u1n8mBDkJREwMsAkCdkwd4Ieqw+x3TUyTsqY0YiBCtE6H6OzzgGk3iuZ3vFWRS+E8/d1g==",
            "typescript-win32-arm64": "sha512-Gyl1Vy6OsWesLzmq+EP0Fb7b4Nid5232AvcA2SFcdYreldpNtYFFofPjnt62y9hQy7VTaZp65ICJjuAQRaVcIQ==",
            "typescript-win32-x64": "sha512-0BQ3HkAHHlKLSp1qRvf3SUhGpGsDuhB/jgFw75guyqbxJqEaS0Cw/VFO8i2nHglJUzQCRtMMR/IBAKE3ETMC4g==",
        },
    },
}

TOOL_VERSIONS = {
    "5.0.2": "sha512-wVORMBGO/FAs/++blGNeAVdbNKtIh1rbBL2EyQ1+J9lClJ93KiiKe8PmFIVdXhHcyv44SL9oglmfeSsndo0jRw==",
    "5.0.3": "sha512-xv8mOEDnigb/tN9PSMTwSEqAnUvkoXMQlicOb0IUVDBSQCgBSaAAROUZYy2IcUy5qU6XajK5jjjO7TMWqBTKZA==",
    "5.0.4": "sha512-cW9T5W9xY37cc+jfEnaUvX91foxtHkza3Nw3wkoF4sSlKn0MONdkdEndig/qPBWXNkmplh3NzayQzCiHM4/hqw==",
    "5.1.3": "sha512-XH627E9vkeqhlZFQuL+UsyAXEnibT0kWR2FWONlr4sTjvxyJYnyefgrkyECLzM5NenmKzRAy2rR/OlYLA1HkZw==",
    "5.1.5": "sha512-FOH+WN/DQjUvN6WgW+c4Ml3yi0PH+a/8q+kNIfRehv1wLhWONedw85iu+vQ39Wp49IzTJEsZ2lyLXpBF7mkF1g==",
    "5.1.6": "sha512-zaWCozRZ6DLEWAWFrVDz1H6FVXzUSfTy5FUMWsQlU8Ym5JP9eO4xkTIROFCQvhQf61z6O/G6ugw3SgAnvvm+HA==",
    "5.2.2": "sha512-mI4WrpHsbCIcwT9cF4FZvr80QUeKvsUsUvKDoR+X/7XHQH98xYD8YHZg7ANtz2GtZt/CBq2QJ0thkGJMHfqc1w==",
    "5.3.2": "sha512-6l+RyNy7oAHDfxC4FzSJcz9vnjTKxrLpDG5M2Vu4SHRVNg6xzqZp6LYSR9zjqQTu8DU/f5xwxUdADOkbrIX2gQ==",
    "5.3.3": "sha512-pXWcraxM0uxAS+tN0AG/BF2TyqmHO014Z070UsJ+pFvYuRSq8KH8DmWpnbXe0pEPDHXZV3FcAbJkijJ5oNEnWw==",
    "5.4.2": "sha512-+2/g0Fds1ERlP6JsakQQDXjZdZMM+rqpamFZJEKh4kwTIn3iDkgKtby0CeNd5ATNZ4Ry1ax15TMx0W2V+miizQ==",
    "5.4.3": "sha512-KrPd3PKaCLr78MalgiwJnA25Nm8HAmdwN3mYUYZgG/wizIo9EainNVQI9/yDavtVFRN2h3k8uf3GLHuhDMgEHg==",
    "5.4.4": "sha512-dGE2Vv8cpVvw28v8HCPqyb08EzbBURxDpuhJvTrusShUfGnhHBafDsLdS1EhhxyL6BJQE+2cT3dDPAv+MQ6oLw==",
    "5.4.5": "sha512-vcI4UpRgg81oIRUFwR0WSIHKt11nJ7SAVlYNIu+QpqeyXP+gpQJy/Z4+F0aGxSE4MqwjyXvW/TzgkLAx2AGHwQ==",
    "5.5.2": "sha512-NcRtPEOsPFFWjobJEtfihkLCZCXZt/os3zf8nTxjVH3RvTSxjrCamJpbExGvYOF+tFHc3pA65qpdwPbzjohhew==",
    "5.5.3": "sha512-/hreyEujaB0w76zKo6717l3L0o/qEUtRgdvUBvlkhoWeOVMjMuHNHk0BRBzikzuGDqNmPQbg5ifMEqsHLiIUcQ==",
    "5.5.4": "sha512-Mtq29sKDAEYP7aljRgtPOpTvOfbwRWlS6dPRzwjdE+C0R4brX/GUyhHSecbHMFLNBLcJIPt9nl9yG5TZ1weH+Q==",
    "5.6.2": "sha512-NW8ByodCSNCwZeghjN3o+JX5OFH0Ojg6sadjEKY4huZ52TqbJTJnDo5+Tw98lSy63NZvi4n+ez5m2u5d4PkZyw==",
    "5.6.3": "sha512-hjcS1mhfuyi4WW8IWtjP7brDrG2cuDZukyrYrSauoXGNgx0S7zceP07adYkJycEr56BOUTNPzbInooiN3fn1qw==",
    "5.7.2": "sha512-i5t66RHxDvVN40HfDd1PsEThGNnlMCMT3jMUuoh9/0TaqWevNontacunWyN02LA9/fIbEWlcHZcgTKb9QoaLfg==",
    "5.7.3": "sha512-84MVSjMEHP+FQRPy3pX9sTVV/INIex71s9TL2Gm5FG/WG1SqXeKyZ0k7/blY/4FdOzI12CBy1vGc4og/eus0fw==",
    "5.8.2": "sha512-aJn6wq13/afZp/jT9QZmwEjDqqvSGp1VT5GVg+f/t6/oVyrgXM6BY1h9BRh/O5p3PlUPAe+WuiEZOmb/49RqoQ==",
    "5.8.3": "sha512-p1diW6TqL9L07nNxvRMM7hMMw4c5XOo/1ibL4aAIGmSAt9slTE1Xgw5KWuof2uTOvCg9BY7ZRi+GaF+7sfgPeQ==",
    "5.9.2": "sha512-CWBzXQrc/qOkhidw1OzBTQuYRbfyxDXJMVJ1XNwUHGROVmuaeiEm3OslpZ1RV96d7SKKjZKrSJu3+t/xlw3R9A==",
    "5.9.3": "sha512-jl1vZzPDinLr9eUt3J/t7V6FgNEw9QjvBPdysz9KfQDD41fQrC2Y4vKQdiaUpFT4bXlb1RHhLpp8wtm6M5TgSw==",
    "6.0.2": "sha512-bGdAIrZ0wiGDo5l8c++HWtbaNCWTS4UTv7RaTH/ThVIgjkveJt83m74bBHMJkuCbslY8ixgLBVZJIOiQlQTjfQ==",
    "6.0.3": "sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/ODjNbr43SsoXqNuAisEf1GdCxqWcdBw==",
}
