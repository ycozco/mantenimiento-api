import { Type } from 'class-transformer';
import { IsBase64, IsInt, IsString, IsUUID, Max, MaxLength, Min, Matches, MinLength } from 'class-validator';

export class PushOperationDto {
  @IsUUID()
  operationId!: string;

  @IsString()
  @Matches(/^[a-z][a-z0-9_]{1,39}$/)
  entityType!: string;

  @IsUUID()
  entityId!: string;

  @IsInt()
  @Min(1)
  @Max(100)
  schemaVersion!: number;

  @IsString()
  @IsBase64()
  @Matches(/^[A-Za-z0-9+/]{16}$/)
  @MaxLength(70000)
  nonce!: string;

  @IsString()
  @IsBase64()
  @MinLength(24)
  @MaxLength(70000)
  ciphertext!: string;
}

export class PullChangesQueryDto {
  @IsString()
  @Matches(/^(0|[1-9][0-9]{0,19})$/)
  cursor = '0';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;
}
