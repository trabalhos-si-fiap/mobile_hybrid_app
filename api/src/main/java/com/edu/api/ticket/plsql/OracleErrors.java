package com.edu.api.ticket.plsql;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.UnprocessableException;
import org.springframework.dao.DataAccessException;

import java.sql.SQLException;

/** Traduz os RAISE_APPLICATION_ERROR das procedures em exceções de domínio. */
final class OracleErrors {

    private OracleErrors() {
    }

    static RuntimeException translate(DataAccessException exception) {
        SQLException sql = sqlCause(exception);
        if (sql != null) {
            String message = userMessage(sql.getMessage());
            switch (sql.getErrorCode()) {
                case 20001: return new NotFoundException(message);
                case 20002: return new ConflictException(message);
                case 20003: return new UnprocessableException(message);
                default: break;
            }
        }
        return exception;
    }

    /**
     * Primeira SQLException da cadeia. Não usa getMostSpecificCause: o ojdbc
     * põe uma OracleDatabaseException (que não é SQLException) como causa raiz.
     */
    private static SQLException sqlCause(Throwable exception) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sql) {
                return sql;
            }
        }
        return null;
    }

    /** "ORA-20002: texto\nORA-06512: ..." → "texto". */
    static String userMessage(String oracleMessage) {
        String firstLine = oracleMessage.lines().findFirst().orElse(oracleMessage);
        return firstLine.replaceFirst("^ORA-\\d+:\\s*", "");
    }
}
