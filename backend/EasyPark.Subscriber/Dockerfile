FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

COPY ["EasyPark.Subscriber/EasyPark.Subscriber.csproj", "EasyPark.Subscriber/"]
COPY ["EasyPark.Model/EasyPark.Model.csproj", "EasyPark.Model/"]
COPY ["EasyPark.Services/EasyPark.Services.csproj", "EasyPark.Services/"]

WORKDIR /app/EasyPark.Subscriber
RUN dotnet restore

COPY . .

RUN dotnet build "EasyPark.Subscriber/EasyPark.Subscriber.csproj" -c Release -o /app/build

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/build .
ENTRYPOINT ["dotnet", "EasyPark.Subscriber.dll"]
